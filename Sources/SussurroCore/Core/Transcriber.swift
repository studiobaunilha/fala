import WhisperKit
import Foundation

// WhisperKit is an open class with no Sendable annotation.
// We own this project and know all calls are serialized through the actor,
// so this is safe.
extension WhisperKit: @unchecked @retroactive Sendable {}

/// Serializes access to WhisperKit. Lazy-loads the model on first use.
public actor Transcriber: AudioTranscribing {
    private var pipe: WhisperKit?
    public let modelName: String

    public init(modelName: String) {
        self.modelName = modelName
    }

    /// Loads the model if not already loaded. Safe to call multiple times.
    public func loadIfNeeded() async throws {
        guard pipe == nil else { return }
        pipe = try await WhisperKit(model: modelName)
    }

    /// Transcribes a [Float] array at 16 kHz mono. Returns trimmed text.
    /// detectLanguage: true → Whisper auto-detects the spoken language (pt-BR, en, etc.)
    public func transcribe(samples: [Float]) async throws -> String {
        try await loadIfNeeded()
        guard let wk = pipe else { throw TranscriberError.notLoaded }
        let options = DecodingOptions(detectLanguage: true)
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
