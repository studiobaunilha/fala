import Foundation

public enum WarmupStatus: Equatable, Sendable {
    case idle
    case warming(String)
    case ready(String)
    case failed(String, String)

    public var isBusy: Bool {
        if case .warming = self {
            return true
        }
        return false
    }
}

@MainActor
public final class WarmupCoordinator: ObservableObject {
    @Published public private(set) var transcriptionStatus: WarmupStatus = .idle
    @Published public private(set) var llmStatus: WarmupStatus = .idle

    private let whisperTranscriber: Transcriber
    private let parakeetTranscriber: ParakeetTranscriber
    private let mlxCatalogService: MLXCatalogService
    private let mlxDownloadWarmupGate: MLXDownloadWarmupGate
    private let configProvider: @MainActor () -> AppConfig
    private let mlxWarmer: @Sendable (String) async throws -> Void

    private var transcriptionTask: Task<Void, Never>?
    private var llmTask: Task<Void, Never>?

    public init(
        whisperTranscriber: Transcriber,
        parakeetTranscriber: ParakeetTranscriber,
        mlxCatalogService: MLXCatalogService,
        mlxDownloadWarmupGate: MLXDownloadWarmupGate = MLXDownloadWarmupGate(),
        configProvider: @escaping @MainActor () -> AppConfig,
        mlxWarmer: @escaping @Sendable (String) async throws -> Void = { repoID in
            try await MLXModelCache.shared.warmup(repoID: repoID)
        }
    ) {
        self.whisperTranscriber = whisperTranscriber
        self.parakeetTranscriber = parakeetTranscriber
        self.mlxCatalogService = mlxCatalogService
        self.mlxDownloadWarmupGate = mlxDownloadWarmupGate
        self.configProvider = configProvider
        self.mlxWarmer = mlxWarmer
    }

    public var isPreparingSelectedResources: Bool {
        transcriptionStatus.isBusy || llmStatus.isBusy
    }

    public func scheduleSelectedWarmup(includeLLM: Bool = true) {
        let config = configProvider()
        warmTranscriptionEngine(config: config)
        if includeLLM {
            warmSelectedLLM(config: config)
        } else {
            llmTask?.cancel()
            llmTask = nil
            llmStatus = .idle
        }
    }

    public func warmTranscriptionEngine(config: AppConfig) {
        transcriptionTask?.cancel()
        transcriptionTask = Task { [weak self] in
            guard let self else { return }
            let label = config.transcriptionEngine == "parakeet"
                ? L10n("Parakeet V3")
                : config.activeWhisperModel

            await MainActor.run {
                self.transcriptionStatus = .warming(label)
            }

            do {
                if config.transcriptionEngine == "parakeet" {
                    try await self.parakeetTranscriber.loadIfNeeded()
                } else {
                    guard self.whisperModelIsAvailable(config.activeWhisperModel) else {
                        await MainActor.run {
                            self.transcriptionStatus = .idle
                        }
                        return
                    }
                    await self.whisperTranscriber.setModel(config.activeWhisperModel)
                    try await self.whisperTranscriber.loadIfNeeded()
                }

                await MainActor.run {
                    self.transcriptionStatus = .ready(label)
                }
            } catch {
                await MainActor.run {
                    self.transcriptionStatus = .failed(label, error.localizedDescription)
                }
            }
        }
    }

    public func warmSelectedLLM(config: AppConfig) {
        llmTask?.cancel()
        llmTask = Task { [weak self] in
            guard let self else { return }
            let effective = config.getEffectiveConfig(for: config.selectedDictationTemplate)
            let provider = effective.provider

            if provider == "mlx" {
                let repoID = effective.model.isEmpty ? config.mlxModel : effective.model
                guard !repoID.isEmpty else {
                    await MainActor.run { self.llmStatus = .idle }
                    return
                }

                guard self.mlxCatalogService.isDownloaded(repoID: repoID) else {
                    await MainActor.run { self.llmStatus = .idle }
                    return
                }

                guard !self.mlxDownloadWarmupGate.isCoolingDown(repoID: repoID) else {
                    await MainActor.run { self.llmStatus = .idle }
                    return
                }

                await MainActor.run {
                    self.llmStatus = .warming(repoID)
                }

                do {
                    try await self.mlxWarmer(repoID)
                    self.mlxDownloadWarmupGate.clear(repoID: repoID)
                    await MainActor.run {
                        self.llmStatus = .ready(repoID)
                    }
                } catch {
                    await MainActor.run {
                        self.llmStatus = .failed(repoID, error.localizedDescription)
                    }
                }
                return
            }

            if provider == "apple" || provider == "gemini" || provider == "openai" {
                await MainActor.run {
                    self.llmStatus = .ready(provider)
                }
            } else {
                await MainActor.run {
                    self.llmStatus = .idle
                }
            }
        }
    }

    private func whisperModelIsAvailable(_ shortId: String) -> Bool {
        guard shortId != "none" else {
            return false
        }
        return ModelManager.scanDirectory(ModelManager.cacheDir).contains {
            $0 == knownModels.first(where: { $0.id == shortId })?.variant
        }
    }
}
