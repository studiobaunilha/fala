import Foundation

struct BatchWhisperTranscriber: AudioTranscribing {
    let supportsTranslation: Bool
    private let loadStateHandler: @Sendable () async -> TranscriberLoadState
    private let loadIfNeededHandler: @Sendable ((@Sendable (Double) -> Void)?) async throws -> Void
    private let setModelHandler: @Sendable (String) async -> Void
    private let setConfigHandler: @Sendable (String, Float, String) async -> Void
    private let transcribeSamplesHandler: @Sendable ([Float], String) async throws -> String
    private let transcribeAudioPathHandler:
        @Sendable (String, String, (@Sendable (TranscriberProgress) -> Void)?) async throws -> String

    init(
        supportsTranslation: Bool = true,
        loadState: @escaping @Sendable () async -> TranscriberLoadState = { .cold },
        loadIfNeeded: @escaping @Sendable ((@Sendable (Double) -> Void)?) async throws -> Void,
        setModel: @escaping @Sendable (String) async -> Void,
        setConfig: @escaping @Sendable (String, Float, String) async -> Void,
        transcribeSamples: @escaping @Sendable ([Float], String) async throws -> String,
        transcribeAudioPath: @escaping @Sendable (
            String,
            String,
            (@Sendable (TranscriberProgress) -> Void)?
        ) async throws -> String
    ) {
        self.supportsTranslation = supportsTranslation
        self.loadStateHandler = loadState
        self.loadIfNeededHandler = loadIfNeeded
        self.setModelHandler = setModel
        self.setConfigHandler = setConfig
        self.transcribeSamplesHandler = transcribeSamples
        self.transcribeAudioPathHandler = transcribeAudioPath
    }

    func loadState() async -> TranscriberLoadState {
        await loadStateHandler()
    }

    func loadIfNeeded(progress: (@Sendable (Double) -> Void)? = nil) async throws {
        try await loadIfNeededHandler(progress)
    }

    func setModel(_ name: String) async {
        await setModelHandler(name)
    }

    func setConfig(language: String, temperature: Float, prompt: String) async {
        await setConfigHandler(language, temperature, prompt)
    }

    func transcribe(samples: [Float], task: String) async throws -> String {
        try await transcribeSamplesHandler(samples, task)
    }

    func transcribe(
        audioPath: String,
        task: String,
        progress: (@Sendable (TranscriberProgress) -> Void)?
    ) async throws -> String {
        try await transcribeAudioPathHandler(audioPath, task, progress)
    }
}

struct BatchPreloadableTranscriber: AudioTranscribing {
    let supportsTranslation: Bool
    private let loadStateHandler: @Sendable () async -> TranscriberLoadState
    private let loadIfNeededHandler: @Sendable ((@Sendable (Double) -> Void)?) async throws -> Void
    private let transcribeSamplesHandler: @Sendable ([Float], String) async throws -> String
    private let transcribeAudioPathHandler:
        @Sendable (String, String, (@Sendable (TranscriberProgress) -> Void)?) async throws -> String

    init(
        supportsTranslation: Bool = false,
        loadState: @escaping @Sendable () async -> TranscriberLoadState = { .cold },
        loadIfNeeded: @escaping @Sendable ((@Sendable (Double) -> Void)?) async throws -> Void,
        transcribeSamples: @escaping @Sendable ([Float], String) async throws -> String,
        transcribeAudioPath: @escaping @Sendable (
            String,
            String,
            (@Sendable (TranscriberProgress) -> Void)?
        ) async throws -> String
    ) {
        self.supportsTranslation = supportsTranslation
        self.loadStateHandler = loadState
        self.loadIfNeededHandler = loadIfNeeded
        self.transcribeSamplesHandler = transcribeSamples
        self.transcribeAudioPathHandler = transcribeAudioPath
    }

    func loadState() async -> TranscriberLoadState {
        await loadStateHandler()
    }

    func loadIfNeeded(progress: (@Sendable (Double) -> Void)? = nil) async throws {
        try await loadIfNeededHandler(progress)
    }

    func transcribe(samples: [Float], task: String) async throws -> String {
        try await transcribeSamplesHandler(samples, task)
    }

    func transcribe(
        audioPath: String,
        task: String,
        progress: (@Sendable (TranscriberProgress) -> Void)?
    ) async throws -> String {
        try await transcribeAudioPathHandler(audioPath, task, progress)
    }
}

@MainActor
final class BatchTranscriberPool {
    typealias WhisperFactory = () -> BatchWhisperTranscriber
    typealias ParakeetFactory = () -> BatchPreloadableTranscriber

    private let whisperFactory: WhisperFactory
    private let parakeetFactory: ParakeetFactory

    private var whisperTranscriber: BatchWhisperTranscriber?
    private var parakeetTranscriber: BatchPreloadableTranscriber?

    init(
        whisperFactory: @escaping WhisperFactory,
        parakeetFactory: @escaping ParakeetFactory
    ) {
        self.whisperFactory = whisperFactory
        self.parakeetFactory = parakeetFactory
    }

    func warm(using config: AppConfig) async throws {
        if config.transcriptionEngine == "parakeet" {
            let transcriber = resolveParakeetTranscriber()
            try await transcriber.loadIfNeeded(progress: nil)
            return
        }

        guard config.activeWhisperModel != "none" else {
            return
        }

        let transcriber = await resolveWhisperTranscriber(
            modelName: config.activeWhisperModel,
            language: config.transcriptionLanguage,
            temperature: config.batchTemperature
        )
        try await transcriber.loadIfNeeded(progress: nil)
    }

    func transcriber(
        using config: AppConfig,
        modelName: String,
        language: String
    ) async -> any AudioTranscribing {
        if config.transcriptionEngine == "parakeet" {
            return resolveParakeetTranscriber()
        }

        return await resolveWhisperTranscriber(
            modelName: modelName,
            language: language,
            temperature: config.batchTemperature
        )
    }
}

private extension BatchTranscriberPool {
    func resolveParakeetTranscriber() -> BatchPreloadableTranscriber {
        if let parakeetTranscriber {
            return parakeetTranscriber
        }

        let created = parakeetFactory()
        parakeetTranscriber = created
        return created
    }

    func resolveWhisperTranscriber(
        modelName: String,
        language: String,
        temperature: Float
    ) async -> BatchWhisperTranscriber {
        let transcriber: BatchWhisperTranscriber
        if let whisperTranscriber {
            transcriber = whisperTranscriber
        } else {
            let created = whisperFactory()
            whisperTranscriber = created
            transcriber = created
        }

        await transcriber.setModel(modelName)
        await transcriber.setConfig(
            language: language,
            temperature: temperature,
            prompt: ""
        )
        return transcriber
    }
}
