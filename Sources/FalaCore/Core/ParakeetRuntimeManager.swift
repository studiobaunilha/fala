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
        try await manager.configureVocabularyBoosting(
            vocabulary: vocabulary,
            ctcModels: ctcModels
        )
    }

    func disableVocabularyBoosting() async {
        manager.disableVocabularyBoosting()
    }

    func transcribe(samples: [Float]) async throws -> String {
        try await initializeIfNeeded()
        let result = try await manager.transcribe(samples, source: .microphone)
        return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func transcribe(audioURL: URL) async throws -> String {
        try await initializeIfNeeded()
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
