import Foundation

/// Transcribes audio using Parakeet TDT v3 via FluidAudio (CoreML/ANE).
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
    public let supportsTranslation = false

    public init() {
        self.runtime = DefaultParakeetRuntimeManager()
        self.vocabularyProvider = {
            AppConfig.load().parakeetVocabularyStore
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

    /// Loads the Parakeet V3 model if not already loaded.
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
        try await loadIfNeeded()
        await refreshVocabularyBoostingIfNeeded()
        return try await runtime.transcribe(samples: samples)
    }

    /// Transcribes a WAV/audio file by path.
    public func transcribe(
        audioPath: String,
        task: String = "transcribe",
        progress: (@Sendable (TranscriberProgress) -> Void)? = nil
    ) async throws -> String {
        try await loadIfNeeded()
        await refreshVocabularyBoostingIfNeeded()
        let url = URL(fileURLWithPath: audioPath)
        let result = try await runtime.transcribe(audioURL: url)
        // Emit a single progress update with the full result
        progress?(TranscriberProgress(text: result, windowId: 0))
        return result
    }
}

private extension ParakeetTranscriber {
    func refreshVocabularyBoostingIfNeeded() async {
        let vocabularyStore = vocabularyProvider()
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
