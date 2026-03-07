import Foundation

public struct TranscriberProgress: Sendable {
    public let text: String
    public let windowId: Int
    
    public init(text: String, windowId: Int) {
        self.text = text
        self.windowId = windowId
    }
}

/// Abstraction over the Whisper transcription engine.
/// Enables testing without loading ML models.
public protocol AudioTranscribing: Sendable {
    var supportsTranslation: Bool { get }
    func transcribe(samples: [Float], task: String) async throws -> String
    func transcribe(
        audioPath: String,
        task: String,
        progress: (@Sendable (TranscriberProgress) -> Void)?
    ) async throws -> String
}

public extension AudioTranscribing {
    var supportsTranslation: Bool { true }

    func transcribe(samples: [Float]) async throws -> String {
        try await transcribe(samples: samples, task: "transcribe")
    }

    func transcribe(audioPath: String) async throws -> String {
        try await transcribe(audioPath: audioPath, task: "transcribe", progress: nil)
    }

    func transcribe(audioPath: String, progress: (@Sendable (TranscriberProgress) -> Void)?) async throws -> String {
        try await transcribe(audioPath: audioPath, task: "transcribe", progress: progress)
    }
}
