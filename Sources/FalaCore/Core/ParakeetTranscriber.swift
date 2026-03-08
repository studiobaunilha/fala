import Foundation
import FluidAudio

/// Transcribes audio using Parakeet TDT v3 via FluidAudio (CoreML/ANE).
/// Conforms to `AudioTranscribing` to be a drop-in alternative to the Whisper `Transcriber`.
///
/// All access is serialized through the actor, so nonisolated(unsafe) is safe here.
/// AsrManager is not Sendable but we own all calls.
public final class ParakeetTranscriber: AudioTranscribing, @unchecked Sendable {
    private var manager: AsrManager?
    private var loadingTask: Task<Void, Error>?
    private var loadingToken: UUID?
    private let lock = NSLock()
    public let supportsTranslation = false

    public init() {}

    /// Loads the Parakeet V3 model if not already loaded.
    public func loadIfNeeded(progress: (@Sendable (Double) -> Void)? = nil) async throws {
        if lock.withLock({ manager != nil }) { return }
        if let loadingTask = lock.withLock({ loadingTask }) {
            try await loadingTask.value
            return
        }

        let token = UUID()
        let task = Task<Void, Error> { [weak self] in
            let downloaded = try await AsrModels.downloadAndLoad(version: .v3)
            let mgr = AsrManager()
            try await mgr.initialize(models: downloaded)
            self?.lock.withLock {
                if self?.manager == nil {
                    self?.manager = mgr
                }
            }
        }

        lock.withLock {
            self.loadingTask = task
            self.loadingToken = token
        }

        do {
            try await task.value
            lock.withLock {
                if self.loadingToken == token {
                    self.loadingTask = nil
                    self.loadingToken = nil
                }
            }
        } catch {
            lock.withLock {
                if self.loadingToken == token {
                    self.loadingTask = nil
                    self.loadingToken = nil
                }
            }
            throw error
        }
    }

    /// Transcribes a [Float] array at 16 kHz mono.
    public func transcribe(samples: [Float], task: String = "transcribe") async throws -> String {
        try await loadIfNeeded()
        guard let mgr = lock.withLock({ manager }) else {
            throw TranscriberError.notLoaded
        }
        let result = try await mgr.transcribe(samples, source: .microphone)
        return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Transcribes a WAV/audio file by path.
    public func transcribe(
        audioPath: String,
        task: String = "transcribe",
        progress: (@Sendable (TranscriberProgress) -> Void)? = nil
    ) async throws -> String {
        try await loadIfNeeded()
        guard let mgr = lock.withLock({ manager }) else {
            throw TranscriberError.notLoaded
        }
        let url = URL(fileURLWithPath: audioPath)
        let result = try await mgr.transcribe(url, source: .microphone)
        // Emit a single progress update with the full result
        progress?(TranscriberProgress(text: result.text, windowId: 0))
        return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
