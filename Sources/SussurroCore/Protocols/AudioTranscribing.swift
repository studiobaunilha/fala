import Foundation

/// Abstraction over the Whisper transcription engine.
/// Enables testing without loading ML models.
public protocol AudioTranscribing: Sendable {
    func transcribe(samples: [Float]) async throws -> String
    func transcribe(audioPath: String) async throws -> String
}
