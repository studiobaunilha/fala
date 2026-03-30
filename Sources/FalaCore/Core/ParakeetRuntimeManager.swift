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
    private let manager: AsrManager
    private var isInitialized = false
    private var ctcModels: CtcModels?
    private let lock = NSLock()
    /// Serializes all AsrManager operations (transcribe, configure, disable vocabulary boosting)
    /// to prevent concurrent access that causes SIGSEGV in FluidAudio's unsynchronized state.
    private let operationLock = AsyncSemaphore(value: 1)

    init(manager: AsrManager = AsrManager()) {
        self.manager = manager
    }

    func initializeIfNeeded() async throws {
        if lock.withLock({ isInitialized }) {
            return
        }

        let downloaded = try await AsrModels.downloadAndLoad(version: .v3)
        try await manager.initialize(models: downloaded)
        lock.withLock {
            isInitialized = true
        }
    }

    func configureVocabularyBoosting(_ vocabulary: CustomVocabularyContext) async throws {
        try await initializeIfNeeded()
        let ctcModels = try await loadCtcModelsIfNeeded()
        await operationLock.wait()
        defer { operationLock.signal() }
        try await manager.configureVocabularyBoosting(
            vocabulary: vocabulary,
            ctcModels: ctcModels
        )
    }

    func disableVocabularyBoosting() async {
        await operationLock.wait()
        defer { operationLock.signal() }
        manager.disableVocabularyBoosting()
    }

    func transcribe(samples: [Float]) async throws -> String {
        try await initializeIfNeeded()
        await operationLock.wait()
        defer { operationLock.signal() }
        let result = try await manager.transcribe(samples, source: .microphone)
        return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func transcribe(audioURL: URL) async throws -> String {
        try await initializeIfNeeded()
        await operationLock.wait()
        defer { operationLock.signal() }
        let result = try await manager.transcribe(audioURL, source: .microphone)
        return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension DefaultParakeetRuntimeManager {
    func loadCtcModelsIfNeeded() async throws -> CtcModels {
        if let ctcModels = lock.withLock({ ctcModels }) {
            return ctcModels
        }

        let loadedModels = try await CtcModels.downloadAndLoad()
        lock.withLock {
            ctcModels = loadedModels
        }
        return loadedModels
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
