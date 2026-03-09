import Foundation

public struct TranscriberProgress: Sendable {
    public let text: String
    public let windowId: Int
    
    public init(text: String, windowId: Int) {
        self.text = text
        self.windowId = windowId
    }
}

public enum TranscriberLoadState: String, Sendable {
    case ready
    case loading
    case cold
}

/// Abstraction over the Whisper transcription engine.
/// Enables testing without loading ML models.
public protocol AudioTranscribing: Sendable {
    var supportsTranslation: Bool { get }
    func loadState() async -> TranscriberLoadState
    func loadIfNeeded(progress: (@Sendable (Double) -> Void)?) async throws
    func transcribe(samples: [Float], task: String) async throws -> String
    func transcribe(
        audioPath: String,
        task: String,
        progress: (@Sendable (TranscriberProgress) -> Void)?
    ) async throws -> String
}

public extension AudioTranscribing {
    var supportsTranslation: Bool { true }

    func loadState() async -> TranscriberLoadState { .cold }

    func loadIfNeeded(progress: (@Sendable (Double) -> Void)? = nil) async throws {}

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
