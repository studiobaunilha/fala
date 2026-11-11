import Foundation

/// Transcribes audio using the selected Parakeet model via FluidAudio (CoreML/ANE).
/// Conforms to `AudioTranscribing` to be a drop-in alternative to the Whisper `Transcriber`.
///
public final class ParakeetTranscriber: AudioTranscribing, @unchecked Sendable {
    private enum VocabularyBoostingState {
        case idle
        case configured(ParakeetVocabularyStore)
        case failed(ParakeetVocabularyStore)

        func matches(_ store: ParakeetVocabularyStore) -> Bool {
            switch self {
            case .idle:
                return store.isEmpty
            case .configured(let currentStore), .failed(let currentStore):
                return currentStore == store
            }
        }
    }

    private let runtime: any ParakeetRuntimeManaging
    private let vocabularyProvider: @Sendable () -> ParakeetVocabularyStore
    private var loadingTask: Task<Void, Error>?
    private var loadingToken: UUID?
    private var didLoad = false
    private var vocabularyBoostingState: VocabularyBoostingState = .idle
    private let lock = NSLock()
    private let operationLock = AsyncSemaphore(value: 1)
    public let supportsTranslation = false

    public init(model: ParakeetModel = AppConfig.load().parakeetModel) {
        self.runtime = DefaultParakeetRuntimeManager(model: model)
        self.vocabularyProvider = {
            AppConfig.load().effectiveVocabularyContext.store
        }
    }

    init(
        runtime: any ParakeetRuntimeManaging,
        vocabularyProvider: @escaping @Sendable () -> ParakeetVocabularyStore
    ) {
        self.runtime = runtime
        self.vocabularyProvider = vocabularyProvider
    }

    public func loadState() async -> TranscriberLoadState {
        if lock.withLock({ didLoad }) {
            return .ready
        }
        if lock.withLock({ loadingTask != nil }) {
            return .loading
        }
        return .cold
    }

    /// Loads the selected model if not already loaded.
    public func loadIfNeeded(progress: (@Sendable (Double) -> Void)? = nil) async throws {
        if lock.withLock({ didLoad }) { return }
        if let loadingTask = lock.withLock({ loadingTask }) {
            try await loadingTask.value
            return
        }

        let token = UUID()
        let task = Task.detached { [runtime] in
            try await runtime.initializeIfNeeded()
        }

        lock.withLock {
            self.loadingTask = task
            self.loadingToken = token
        }

        do {
            try await task.value
            lock.withLock {
                if self.loadingToken == token {
                    self.didLoad = true
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
        try await transcribe(samples: samples, vocabulary: vocabularyProvider())
    }

    /// Transcribes a WAV/audio file by path.
    public func transcribe(
        audioPath: String,
        task: String = "transcribe",
        progress: (@Sendable (TranscriberProgress) -> Void)? = nil
    ) async throws -> String {
        try await transcribe(audioPath: audioPath, vocabulary: vocabularyProvider(), progress: progress)
    }

    func scoped(to vocabulary: ParakeetVocabularyStore) -> any AudioTranscribing {
        VocabularyScopedParakeetTranscriber(parent: self, vocabulary: vocabulary)
    }

    fileprivate func transcribe(samples: [Float], vocabulary: ParakeetVocabularyStore) async throws -> String {
        await operationLock.wait()
        defer { operationLock.signal() }
        try Task.checkCancellation()
        try await loadIfNeeded()
        await refreshVocabularyBoostingIfNeeded(vocabulary)
        return try await runtime.transcribe(samples: samples)
    }

    fileprivate func transcribe(
        audioPath: String,
        vocabulary: ParakeetVocabularyStore,
        progress: (@Sendable (TranscriberProgress) -> Void)?
    ) async throws -> String {
        await operationLock.wait()
        defer { operationLock.signal() }
        try Task.checkCancellation()
        try await loadIfNeeded()
        await refreshVocabularyBoostingIfNeeded(vocabulary)
        let result = try await runtime.transcribe(audioURL: URL(fileURLWithPath: audioPath))
        progress?(TranscriberProgress(text: result, windowId: 0))
        return result
    }
}

private extension ParakeetTranscriber {
    func refreshVocabularyBoostingIfNeeded(_ vocabularyStore: ParakeetVocabularyStore) async {
        let currentState = lock.withLock { vocabularyBoostingState }

        if currentState.matches(vocabularyStore) {
            return
        }

        guard let vocabularyContext = vocabularyStore.customVocabularyContext else {
            await runtime.disableVocabularyBoosting()
            lock.withLock {
                vocabularyBoostingState = .idle
            }
            return
        }

        do {
            try await runtime.configureVocabularyBoosting(vocabularyContext)
            lock.withLock {
                vocabularyBoostingState = .configured(vocabularyStore)
            }
        } catch is CancellationError {
            // Cancelled by a newer refresh — don't change state.
        } catch {
            await runtime.disableVocabularyBoosting()
            lock.withLock {
                vocabularyBoostingState = .failed(vocabularyStore)
            }
            print("[Fala] Parakeet vocabulary boosting unavailable: \(error)")
        }
    }
}

private struct VocabularyScopedParakeetTranscriber: AudioTranscribing {
    let parent: ParakeetTranscriber
    let vocabulary: ParakeetVocabularyStore
    let supportsTranslation = false

    func loadState() async -> TranscriberLoadState { await parent.loadState() }

    func loadIfNeeded(progress: (@Sendable (Double) -> Void)?) async throws {
        try await parent.loadIfNeeded(progress: progress)
    }

    func transcribe(samples: [Float], task: String) async throws -> String {
        try await parent.transcribe(samples: samples, vocabulary: vocabulary)
    }

    func transcribe(
        audioPath: String, task: String,
        progress: (@Sendable (TranscriberProgress) -> Void)?
    ) async throws -> String {
        try await parent.transcribe(audioPath: audioPath, vocabulary: vocabulary, progress: progress)
    }
}
