import WhisperKit
import Foundation

// We own this project and know all calls are serialized through the actor,
// so this is safe.
extension WhisperKit: @unchecked @retroactive Sendable {}

/// Serializes access to WhisperKit. Lazy-loads the model on first use.
public actor Transcriber: AudioTranscribing {
    private var pipe: WhisperKit?
    public private(set) var modelName: String
    /// BCP-47 language code, or "auto" for automatic detection.
    public var language: String
    public var temperature: Float
    public var prompt: String

    public init(modelName: String, language: String = "auto", temperature: Float = 0.0, prompt: String = "") {
        self.modelName = modelName
        self.language = language
        self.temperature = temperature
        self.prompt = prompt
    }

    /// Loads the model if not already loaded. Safe to call multiple times.
    public func loadIfNeeded() async throws {
        guard pipe == nil else { return }
        // Resolve short id (e.g. "large-v3-turbo") to full variant name
        // (e.g. "openai_whisper-large-v3_turbo") that WhisperKit expects.
        let variant = knownModels.first { $0.id == modelName }?.variant ?? modelName
        pipe = try await WhisperKit(model: variant)
    }

    /// Updates the active model. Resets the pipeline so it reloads on next use.
    public func setModel(_ name: String) {
        guard name != modelName else { return }
        modelName = name
        pipe = nil
    }

    /// Updates the transcription configuration. Takes effect on next transcription.
    public func setConfig(language: String, temperature: Float, prompt: String) {
        self.language = language
        self.temperature = temperature
        self.prompt = prompt
    }
    
    // For backwards compatibility
    public func setLanguage(_ lang: String) {
        self.language = lang
    }

    /// Transcribes a [Float] array at 16 kHz mono. Returns trimmed text.
    public func transcribe(samples: [Float]) async throws -> String {
        try await loadIfNeeded()
        guard let wk = pipe else { throw TranscriberError.notLoaded }
        let isAuto = language == "auto"
        var options = DecodingOptions(
            language: isAuto ? nil : language,
            temperature: temperature,
            detectLanguage: isAuto,
            skipSpecialTokens: true,
            withoutTimestamps: true
        )
        if !prompt.isEmpty, let tokenizer = wk.tokenizer {
            let tokens = try? await tokenizer.encode(text: prompt)
            options.promptTokens = tokens
        }
        let results = try await wk.transcribe(audioArray: samples, decodeOptions: options)
        let text = results.compactMap { $0.text }.joined(separator: " ")
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return text
    }

    /// Transcribes a WAV/audio file by path. Returns text with newline-joined segments.
    public func transcribe(
        audioPath: String,
        progress: (@Sendable (String) -> Void)? = nil
    ) async throws -> String {
        try await loadIfNeeded()
        guard let wk = pipe else { throw TranscriberError.notLoaded }
        let isAuto = language == "auto"
        var options = DecodingOptions(
            language: isAuto ? nil : language,
            temperature: temperature,
            detectLanguage: isAuto,
            skipSpecialTokens: true,
            withoutTimestamps: true
        )
        if !prompt.isEmpty, let tokenizer = wk.tokenizer {
            let tokens = try? await tokenizer.encode(text: prompt)
            options.promptTokens = tokens
        }
        
        let callback: TranscriptionCallback = { progressData in
            progress?(progressData.text)
            return true
        }
        
        let results = try await wk.transcribe(audioPath: audioPath, decodeOptions: options, callback: callback)
        return results.compactMap { $0.text }.joined(separator: "\n")
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
}
