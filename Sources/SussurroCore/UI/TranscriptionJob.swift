import SwiftUI
import AppKit

// MARK: – State

public enum TranscriptionState: Equatable {
    case idle
    case converting
    case transcribing(String)
    case processingLLM
    case done(String)  // output file path
    case error(String)
}

// MARK: – View Model

@MainActor
public final class TranscriptionJob: ObservableObject {
    @Published public var inputURL: URL?
    @Published public var state: TranscriptionState = .idle
    @Published public var outputFormat: String
    @Published public var outputDirectory: URL?
    
    // Per-job overrides
    @Published public var overrideModel: String?
    @Published public var overrideLanguage: String?
    @Published public var enableDiarization: Bool
    
    private var currentTask: Task<Void, Never>?

    public init() {
        let config = AppConfig.load()
        self.outputFormat = config.outputFormat
        if !config.defaultExportPath.isEmpty {
            self.outputDirectory = URL(fileURLWithPath: config.defaultExportPath)
        }
        self.enableDiarization = config.enableDiarization
    }

    public func selectFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = BatchMode.supportedExtensions.compactMap {
            .init(filenameExtension: $0)
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        inputURL = url
        state = .idle
    }
    
    public func selectOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            outputDirectory = url
        }
    }

    public func transcribe() {
        guard let inputURL else { return }
        let ext = inputURL.pathExtension.lowercased()

        withAnimation(AnimationConfig.standard) {
            state = ext == "wav" ? .transcribing("") : .converting
        }

        currentTask = Task {
            await runTranscriptionTask(inputURL: inputURL, ext: ext)
        }
    }
    
    private func runTranscriptionTask(inputURL: URL, ext: String) async {
        do {
            try Task.checkCancellation()
            let (wavURL, needsCleanup) = try await prepareAudio(from: inputURL, ext: ext)
            defer {
                if needsCleanup { try? FileManager.default.removeItem(at: wavURL) }
            }

            try Task.checkCancellation()
            await MainActor.run {
                withAnimation(AnimationConfig.standard) { state = .transcribing("") }
            }
            
            try await executeTranscription(wavURL: wavURL, inputURL: inputURL)

        } catch is CancellationError {
            await MainActor.run {
                withAnimation(AnimationConfig.standard) { state = .error("Cancelado pelo usuário") }
            }
        } catch {
            await MainActor.run {
                withAnimation(AnimationConfig.standard) { state = .error(error.localizedDescription) }
            }
        }
    }
    
    private func executeTranscription(wavURL: URL, inputURL: URL) async throws {
        let config = AppConfig.load()
        let format = outputFormat
        
        let baseDir = outputDirectory ?? inputURL.deletingLastPathComponent()
        let outputURL = baseDir
            .appendingPathComponent(inputURL.deletingPathExtension().lastPathComponent)
            .appendingPathExtension(format)
        
        try self.initializeOutputFile(url: outputURL, format: format, inputURL: inputURL)
        
        let effectiveModel = overrideModel ?? config.batchModel
        let effectiveLanguage = overrideLanguage ?? config.language

        let transcriber = Transcriber(
            modelName: effectiveModel,
            language: effectiveLanguage,
            temperature: config.batchTemperature,
            prompt: "Keywords: " + config.customDictionary.joined(separator: ", ") + "."
        )
        
        let (stream, continuation) = AsyncStream<TranscriberProgress>.makeStream()
        let processingTask = createProcessingTask(
            stream: stream,
            config: config,
            format: format,
            outputURL: outputURL,
            inputURL: inputURL
        )
        
        let rawFinalText = try await transcriber.transcribe(audioPath: wavURL.path) { progressUpdate in
            continuation.yield(progressUpdate)
        }
        continuation.finish()
        
        _ = await processingTask.value
        try Task.checkCancellation()
        
        await MainActor.run {
            withAnimation(AnimationConfig.standard) { state = .done(outputURL.path) }
        }
    }
    
    private func createTranscriber(config: AppConfig) -> Transcriber {
        Transcriber(
            modelName: overrideModel ?? config.batchModel,
            language: overrideLanguage ?? config.language,
            temperature: config.batchTemperature,
            prompt: "Keywords: " + config.customDictionary.joined(separator: ", ") + "."
        )
    }
    
    public func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }

    func revealInFinder() {
        if case .done(let path) = state {
            NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
        }
    }

    func reset() {
        inputURL = nil
        overrideModel = nil
        overrideLanguage = nil
        state = .idle
    }
}
