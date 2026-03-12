import WhisperKit
import Foundation

// We own this project and know all calls are serialized through the actor,
// so this is safe.
extension WhisperKit: @unchecked @retroactive Sendable {}

/// Serializes access to WhisperKit. Lazy-loads the model on first use.
public actor Transcriber: AudioTranscribing {
    private var pipe: WhisperKit?
    private var loadingTask: Task<WhisperKit, Error>?
    private var loadingToken: UUID?
    private var loadingVariant: String?
    public private(set) var modelName: String
    public let supportsTranslation = true
    /// BCP-47 language code, or "auto" for automatic detection.
    public var language: String
    public var temperature: Float
    public var prompt: String
    public let disableNeuralEngine: Bool

    public init(
        modelName: String,
        language: String = "auto",
        temperature: Float = 0.0,
        prompt: String = "",
        disableNeuralEngine: Bool = false
    ) {
        self.modelName = modelName
        self.language = language
        self.temperature = temperature
        self.prompt = prompt
        self.disableNeuralEngine = disableNeuralEngine
    }

    public func loadState() async -> TranscriberLoadState {
        if pipe != nil {
            return .ready
        }
        if loadingTask != nil {
            return .loading
        }
        return .cold
    }

    /// Loads the model if not already loaded. Safe to call multiple times.
    public func loadIfNeeded(progress: (@Sendable (Double) -> Void)? = nil) async throws {
        guard pipe == nil else { return }
        let variant = resolvedVariant(for: modelName)

        if let loadingTask, loadingVariant == variant {
            let loaded = try await loadingTask.value
            if loadingVariant == variant {
                pipe = loaded
                self.loadingTask = nil
                loadingToken = nil
                loadingVariant = nil
            }
            return
        }

        let token = UUID()
        let task = Task<WhisperKit, Error> {
            if let progress {
                _ = try await WhisperKit.download(variant: variant) { progressUpdate in
                    progress(progressUpdate.fractionCompleted)
                }
            }

            var config = WhisperKitConfig()
            config.verbose = true
            config.logLevel = .debug
            config.model = variant
            
            if disableNeuralEngine {
                var computeOptions = ModelComputeOptions()
                computeOptions.audioEncoderCompute = .cpuAndGPU
                computeOptions.textDecoderCompute = .cpuAndGPU
                config.computeOptions = computeOptions
            }

            return try await WhisperKit(config)
        }

        loadingTask = task
        loadingToken = token
        loadingVariant = variant

        do {
            let loaded = try await task.value
            if loadingToken == token, loadingVariant == variant {
                pipe = loaded
                loadingTask = nil
                loadingToken = nil
                loadingVariant = nil
            }
        } catch {
            if loadingToken == token {
                loadingTask = nil
                loadingToken = nil
                loadingVariant = nil
            }
            throw error
        }
    }

    /// Updates the active model. Resets the pipeline so it reloads on next use.
    public func setModel(_ name: String) async {
        guard name != modelName else { return }
        loadingTask?.cancel()
        loadingTask = nil
        loadingToken = nil
        loadingVariant = nil
        modelName = name
        pipe = nil
    }

    /// Updates the transcription configuration. Takes effect on next transcription.
    public func setConfig(language: String, temperature: Float, prompt: String) async {
        self.language = language
        self.temperature = temperature
        self.prompt = prompt
    }
    
    // For backwards compatibility
    public func setLanguage(_ lang: String) {
        self.language = lang
    }

    /// Transcribes a [Float] array at 16 kHz mono. Returns trimmed text.
    public func transcribe(samples: [Float], task: String = "transcribe") async throws -> String {
        try await loadIfNeeded()
        guard let wk = pipe else { throw TranscriberError.notLoaded }
        let decodeTask: DecodingTask = task == "translate" ? .translate : .transcribe
        let isAuto = language == "auto"
        var options = DecodingOptions(
            task: decodeTask,
            language: isAuto ? nil : language,
            temperature: temperature,
            detectLanguage: isAuto,
            skipSpecialTokens: false,
            withoutTimestamps: false
        )
        if !prompt.isEmpty, let tokenizer = wk.tokenizer {
            let tokens = tokenizer.encode(text: prompt)
                .filter { $0 < tokenizer.specialTokens.specialTokenBegin }
            options.promptTokens = tokens
        }
        let results = try await wk.transcribe(audioArray: samples, decodeOptions: options)
        let rawText = results.compactMap { $0.text }.joined(separator: " ")
        let cleanText = rawText.replacingOccurrences(
            of: "<\\|.*?\\|>",
            with: "",
            options: NSString.CompareOptions.regularExpression
        ).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return cleanText
    }

    /// Transcribes a WAV/audio file by path. Returns text with newline-joined segments.
    public func transcribe(
        audioPath: String,
        task: String = "transcribe",
        progress: (@Sendable (TranscriberProgress) -> Void)? = nil
    ) async throws -> String {
        try await loadIfNeeded()
        guard let wk = pipe else { throw TranscriberError.notLoaded }
        let decodeTask: DecodingTask = task == "translate" ? .translate : .transcribe
        let isAuto = language == "auto"
        var options = DecodingOptions(
            task: decodeTask,
            language: isAuto ? nil : language,
            temperature: temperature,
            detectLanguage: isAuto,
            skipSpecialTokens: false,
            withoutTimestamps: false
        )
        if !prompt.isEmpty, let tokenizer = wk.tokenizer {
            let tokens = tokenizer.encode(text: prompt)
                .filter { $0 < tokenizer.specialTokens.specialTokenBegin }
            options.promptTokens = tokens
        }
        
        let callback: TranscriptionCallback = { progressData in
            if Task.isCancelled {
                return false
            }
            let update = TranscriberProgress(
                text: progressData.text,
                windowId: progressData.windowId
            )
            progress?(update)
            return !Task.isCancelled
        }
        
        let results = try await wk.transcribe(audioPath: audioPath, decodeOptions: options, callback: callback)
        let rawText = results.compactMap { $0.text }.joined(separator: "\n")
        let cleanText = rawText.replacingOccurrences(
            of: "<\\|.*?\\|>",
            with: "",
            options: NSString.CompareOptions.regularExpression
        ).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return cleanText
    }
}

private extension Transcriber {
    func resolvedVariant(for shortId: String) -> String {
        knownModels.first { $0.id == shortId }?.variant ?? shortId
    }
}
