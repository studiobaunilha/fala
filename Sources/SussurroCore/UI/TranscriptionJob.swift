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
        
        // Calculate Output URL early
        let baseDir = outputDirectory ?? inputURL.deletingLastPathComponent()
        let outputURL = baseDir
            .appendingPathComponent(inputURL.deletingPathExtension().lastPathComponent)
            .appendingPathExtension(format)
        
        // Initialize Output File
        try self.initializeOutputFile(url: outputURL, format: format, inputURL: inputURL)
        
        let effectiveModel = overrideModel ?? config.batchModel
        let effectiveLanguage = overrideLanguage ?? config.language

        let transcriber = Transcriber(
            modelName: effectiveModel,
            language: effectiveLanguage,
            temperature: config.batchTemperature,
            prompt: config.customDictionary.joined(separator: ", ")
        )
        
        let text = try await transcriber.transcribe(audioPath: wavURL.path) { partialText in
            Task { @MainActor in
                if case .transcribing = self.state {
                    self.state = .transcribing(partialText)
                }
            }
        }
        
        try Task.checkCancellation()
        try await processOutput(
            text: text,
            inputURL: inputURL,
            config: config,
            format: format,
            outputURL: outputURL
        )
    }
    
    public func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }

    private func processOutput(
        text: String,
        inputURL: URL,
        config: AppConfig,
        format: String,
        outputURL: URL
    ) async throws {
        var finalText = text
        
        if config.enableLLMPostProcessing {
            try Task.checkCancellation()
            if config.llmProvider == "gemini", !config.geminiKey.isEmpty {
                await MainActor.run {
                    withAnimation(AnimationConfig.standard) { state = .processingLLM }
                }
                finalText = try await processWithGemini(
                    text: finalText, prompt: config.llmPrompt, apiKey: config.geminiKey
                )
            } else if config.llmProvider == "openai", !config.openAIKey.isEmpty {
                await MainActor.run {
                    withAnimation(AnimationConfig.standard) { state = .processingLLM }
                }
                finalText = try await processWithOpenAI(
                    text: finalText, prompt: config.llmPrompt, apiKey: config.openAIKey
                )
            }
            
            // Only overwrite if LLM processing succeeded
            let content = format == "md"
                ? "# \(inputURL.deletingPathExtension().lastPathComponent)\n\n\(finalText)\n"
                : finalText + "\n"

            try content.write(to: outputURL, atomically: true, encoding: .utf8)
        }
        
        if !config.enableLLMPostProcessing {
             let content = format == "md"
                ? "# \(inputURL.deletingPathExtension().lastPathComponent)\n\n\(finalText)\n"
                : finalText + "\n"
             try content.write(to: outputURL, atomically: true, encoding: .utf8)
        }
        
        await MainActor.run {
            withAnimation(AnimationConfig.standard) { state = .done(outputURL.path) }
        }
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
