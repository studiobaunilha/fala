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

public struct BatchProcessingWarning: Equatable, Sendable {
    public let title: String
    public let message: String

    public init(title: String, message: String) {
        self.title = title
        self.message = message
    }
}

// MARK: – View Model

@MainActor
public final class TranscriptionJob: ObservableObject {
    @Published public var inputURL: URL?
    @Published public var state: TranscriptionState = .idle
    @Published public var outputFormat: String
    @Published public var outputDirectory: URL?
    @Published public var batchPostPrompt: String = ""
    @Published public var processingWarning: BatchProcessingWarning?

    // Per-job overrides
    @Published public var overrideModel: String?
    @Published public var overrideLanguage: String?
    
    // Dependency
    @Published public var appSettings: AppSettings
    private var currentTask: Task<Void, Never>?
    private var preparationTask: Task<Void, Never>?
    private let batchTranscriberPool: BatchTranscriberPool

    public convenience init(appSettings: AppSettings) {
        self.init(appSettings: appSettings, batchTranscriberPool: nil)
    }

    init(
        appSettings: AppSettings,
        batchTranscriberPool: BatchTranscriberPool?
    ) {
        self.appSettings = appSettings
        let config = AppConfig.load()
        self.outputFormat = config.outputFormat
        if !config.defaultExportPath.isEmpty {
            self.outputDirectory = URL(fileURLWithPath: config.defaultExportPath)
        }
        self.batchTranscriberPool = batchTranscriberPool ?? Self.makeDefaultBatchTranscriberPool(config: config)
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
        processingWarning = nil
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
        processingWarning = nil
        prepareForUse()
        if let issue = appSettings.readiness.primaryIssueForBatch(batchPrompt: batchPostPrompt) {
            withAnimation(AnimationConfig.standard) {
                state = .error(issue.message)
            }
            return
        }
        let ext = inputURL.pathExtension.lowercased()

        withAnimation(AnimationConfig.standard) {
            state = ext == "wav" ? .transcribing("") : .converting
        }

        currentTask = Task {
            await runTranscriptionTask(inputURL: inputURL, ext: ext)
        }
    }
}

private extension TranscriptionJob {
    static func makeDefaultBatchTranscriberPool(config: AppConfig) -> BatchTranscriberPool {
        BatchTranscriberPool(
            whisperFactory: {
                makeWhisperBatchTranscriber(config: config)
            },
            parakeetFactory: {
                makeParakeetBatchTranscriber()
            }
        )
    }

    static func makeWhisperBatchTranscriber(config: AppConfig) -> BatchWhisperTranscriber {
        let transcriber = Transcriber(
            modelName: config.batchModel,
            language: config.transcriptionLanguage,
            temperature: config.batchTemperature,
            prompt: ""
        )
        return BatchWhisperTranscriber(
            loadIfNeeded: { progress in
                try await transcriber.loadIfNeeded(progress: progress)
            },
            setModel: { modelName in
                await transcriber.setModel(modelName)
            },
            setConfig: { language, temperature, prompt in
                await transcriber.setConfig(
                    language: language,
                    temperature: temperature,
                    prompt: prompt
                )
            },
            transcribeSamples: { samples, task in
                try await transcriber.transcribe(samples: samples, task: task)
            },
            transcribeAudioPath: { audioPath, task, progress in
                try await transcriber.transcribe(
                    audioPath: audioPath,
                    task: task,
                    progress: progress
                )
            }
        )
    }

    static func makeParakeetBatchTranscriber() -> BatchPreloadableTranscriber {
        let transcriber = ParakeetTranscriber()
        return BatchPreloadableTranscriber(
            loadIfNeeded: { progress in
                try await transcriber.loadIfNeeded(progress: progress)
            },
            transcribeSamples: { samples, task in
                try await transcriber.transcribe(samples: samples, task: task)
            },
            transcribeAudioPath: { audioPath, task, progress in
                try await transcriber.transcribe(
                    audioPath: audioPath,
                    task: task,
                    progress: progress
                )
            }
        )
    }
}

extension TranscriptionJob {
    public func prepareForUse() {
        preparationTask?.cancel()
        let config = preparationConfig()
        preparationTask = Task { [batchTranscriberPool] in
            do {
                try await batchTranscriberPool.warm(using: config)
            } catch is CancellationError {
                return
            } catch {
                NSLog("[Fala] Batch warmup failed: %@", error.localizedDescription)
            }
        }
    }

    public func cancel() {
        currentTask?.cancel()
        currentTask = nil
        preparationTask?.cancel()
        preparationTask = nil
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
        processingWarning = nil
        state = .idle
    }
}

private extension TranscriptionJob {
    func preparationConfig() -> AppConfig {
        var config = appSettings.snapshotConfig()
        config.batchModel = overrideModel ?? config.batchModel
        config.transcriptionLanguage = overrideLanguage ?? config.transcriptionLanguage
        return config
    }

    func runTranscriptionTask(inputURL: URL, ext: String) async {
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

    func executeTranscription(wavURL: URL, inputURL: URL) async throws {
        var config = preparationConfig()
        config.enableDiarization = appSettings.enableDiarization
        let format = outputFormat

        let baseDir = outputDirectory ?? inputURL.deletingLastPathComponent()
        let outputURL = baseDir
            .appendingPathComponent(inputURL.deletingPathExtension().lastPathComponent)
            .appendingPathExtension(format)

        try self.initializeOutputFile(url: outputURL, format: format, inputURL: inputURL)

        let effectiveModel = overrideModel ?? config.batchModel
        let effectiveLanguage = overrideLanguage ?? config.transcriptionLanguage

        let transcriber = await batchTranscriberPool.transcriber(
            using: config,
            modelName: effectiveModel,
            language: effectiveLanguage
        )

        let (stream, continuation) = AsyncStream<TranscriberProgress>.makeStream()
        let processingTask = createProcessingTask(
            stream: stream,
            config: config,
            template: batchPostPrompt.isEmpty ? .raw : .custom,
            format: format,
            outputURL: outputURL,
            inputURL: inputURL,
            batchPromptOverride: batchPostPrompt.isEmpty ? nil : batchPostPrompt
        )

        _ = try await transcriber.transcribe(audioPath: wavURL.path) { progressUpdate in
            continuation.yield(progressUpdate)
        }
        continuation.finish()

        if !batchPostPrompt.isEmpty {
            await MainActor.run {
                withAnimation(AnimationConfig.standard) {
                    self.state = .processingLLM
                }
            }
        }

        let processingResult = await processingTask.value
        await MainActor.run {
            self.processingWarning = processingResult.warning
        }
        try Task.checkCancellation()

        await MainActor.run {
            withAnimation(AnimationConfig.standard) { state = .done(outputURL.path) }
        }
    }
}
