import WhisperKit
import Foundation

// WhisperKit is an open class with no Sendable annotation.
// We own this project and know all calls are serialized through the actor,
// so this is safe.
extension WhisperKit: @unchecked @retroactive Sendable {}

/// Serializes access to WhisperKit. Lazy-loads the model on first use.
public actor Transcriber: AudioTranscribing {
    private var pipe: WhisperKit?
    public private(set) var modelName: String
    /// BCP-47 language code, or "auto" for automatic detection.
    public var language: String = "auto"

    public init(modelName: String, language: String = "auto") {
        self.modelName = modelName
        self.language = language
    }

    /// Loads the model if not already loaded. Safe to call multiple times.
    public func loadIfNeeded() async throws {
        guard pipe == nil else { return }
        pipe = try await WhisperKit(model: modelName)
    }

    /// Updates the active model. Resets the pipeline so it reloads on next use.
    public func setModel(_ name: String) {
        guard name != modelName else { return }
        modelName = name
        pipe = nil
    }

    /// Updates the transcription language. Takes effect on next transcription.
    public func setLanguage(_ lang: String) {
        language = lang
    }

    /// Transcribes a [Float] array at 16 kHz mono. Returns trimmed text.
    public func transcribe(samples: [Float]) async throws -> String {
        try await loadIfNeeded()
        guard let wk = pipe else { throw TranscriberError.notLoaded }
        let isAuto = language == "auto"
        let options = DecodingOptions(
            language: isAuto ? nil : language,
            detectLanguage: isAuto
        )
        let results = try await wk.transcribe(audioArray: samples, decodeOptions: options)
        let text = results.compactMap { $0.text }.joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text
    }

    /// Transcribes a WAV/audio file by path. Returns text with newline-joined segments.
    public func transcribe(audioPath: String) async throws -> String {
        try await loadIfNeeded()
        guard let wk = pipe else { throw TranscriberError.notLoaded }
        let results = try await wk.transcribe(audioPath: audioPath)
        return results.compactMap { $0.text }.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
