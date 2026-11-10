import Foundation
import FluidAudio

protocol ParakeetRuntimeManaging: Sendable {
    func initializeIfNeeded() async throws
    func configureVocabularyBoosting(_ vocabulary: CustomVocabularyContext) async throws
    func disableVocabularyBoosting() async
    func transcribe(samples: [Float]) async throws -> String
    func transcribe(audioURL: URL) async throws -> String
}

final class DefaultParakeetRuntimeManager: ParakeetRuntimeManaging, @unchecked Sendable {
    static let vocabularyThresholds = VocabularyBoostingSession.Thresholds(cbw: 0, minSimilarity: 0.7)
    private let manager: AsrManager
    private let model: ParakeetModel
    private var isInitialized = false
    private var ctcModels: CtcModels?
    private var vocabularySession: VocabularyBoostingSession?
    // Actor reentrancy must not interleave vocabulary configuration with an inference request.
    private let operationLock = AsyncSemaphore(value: 1)

    init(model: ParakeetModel = .ultra, manager: AsrManager = AsrManager()) {
        self.model = model
        self.manager = manager
    }

    func initializeIfNeeded() async throws {
        await operationLock.wait()
        defer { operationLock.signal() }
        guard !isInitialized else { return }
        let version: AsrModelVersion = model == .ultra ? .ultra : .v3
        let downloaded = try await AsrModels.downloadAndLoad(version: version)
        try await manager.loadModels(downloaded)
        isInitialized = true
    }

    func configureVocabularyBoosting(_ vocabulary: CustomVocabularyContext) async throws {
        try await initializeIfNeeded()
        await operationLock.wait()
        defer { operationLock.signal() }
        let models: CtcModels
        if let ctcModels {
            models = ctcModels
        } else {
            models = try await CtcModels.downloadAndLoad()
            ctcModels = models
        }
        // Upstream's dictation preset requires stronger acoustic evidence to avoid false corrections.
        vocabularySession = try await VocabularyBoostingSession(
            vocabulary: vocabulary,
            ctcModels: models,
            thresholds: Self.vocabularyThresholds
        )
    }

    func disableVocabularyBoosting() async {
        await operationLock.wait()
        defer { operationLock.signal() }
        vocabularySession = nil
    }

    func transcribe(samples: [Float]) async throws -> String {
        await operationLock.wait()
        defer { operationLock.signal() }
        return try await transcribeLocked(samples: samples)
    }

    func transcribe(audioURL: URL) async throws -> String {
        await operationLock.wait()
        defer { operationLock.signal() }
        if vocabularySession != nil {
            let samples = try AudioConverter.toFloat16k(from: audioURL) { try Task.checkCancellation() }
            return try await transcribeLocked(samples: samples)
        }
        var state = try TdtDecoderState()
        let result = try await manager.transcribe(audioURL, decoderState: &state)
        return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func transcribeLocked(samples: [Float]) async throws -> String {
        try Task.checkCancellation()
        var state = try TdtDecoderState()
        let result = try await manager.transcribe(samples, decoderState: &state)
        guard let vocabularySession,
              let timings = result.tokenTimings,
              let rescored = await vocabularySession.rescore(
                text: result.text, tokenTimings: timings, audioSamples: samples
              )
        else {
            return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return rescored.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// A simple async semaphore for serializing access to a shared resource.
/// Used as a mutual-exclusion lock (value: 1) to prevent concurrent AsrManager operations.
private final class AsyncSemaphore: @unchecked Sendable {
    private var permits: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private let lock = NSLock()

    init(value: Int) {
        self.permits = value
    }

    func wait() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            lock.lock()
            if permits > 0 {
                permits -= 1
                lock.unlock()
                continuation.resume()
            } else {
                waiters.append(continuation)
                lock.unlock()
            }
        }
    }

    func signal() {
        lock.lock()
        if !waiters.isEmpty {
            let next = waiters.removeFirst()
            lock.unlock()
            next.resume()
        } else {
            permits += 1
            lock.unlock()
        }
    }
}
