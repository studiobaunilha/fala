import XCTest
@testable import FalaCore

@MainActor
final class WarmupCoordinatorTests: XCTestCase {
    func testWarmSelectedLLMSkipsRecentlyDownloadedMLXModel() async {
        let repoID = "mlx-community/Qwen3-4B-4bit"
        let modelManager = MLXModelManager()
        let catalogService = makeCatalogService(manager: modelManager, repoID: repoID)
        modelManager.localModels = [repoID]

        let gate = MLXDownloadWarmupGate(cooldownInterval: 45)
        gate.recordCompletion(repoID: repoID)

        let warmer = MLXWarmupSpy()
        let coordinator = WarmupCoordinator(
            whisperTranscriber: Transcriber(modelName: "small"),
            parakeetTranscriber: ParakeetTranscriber(),
            mlxCatalogService: catalogService,
            mlxDownloadWarmupGate: gate,
            configProvider: { AppConfig() },
            mlxWarmer: { repoID in
                await warmer.record(repoID: repoID)
            }
        )

        var config = AppConfig()
        config.llmProvider = "mlx"
        config.mlxModel = repoID
        config.selectedDictationTemplate = .askAI

        coordinator.warmSelectedLLM(config: config)
        try? await Task.sleep(for: .milliseconds(20))

        let calledRepoIDs = await warmer.calledRepoIDs()

        XCTAssertEqual(calledRepoIDs, [])
        XCTAssertEqual(coordinator.llmStatus, .idle)
    }

    func testWarmSelectedLLMWarmsDownloadedMLXModelOutsideCooldown() async {
        let repoID = "mlx-community/Qwen3-4B-4bit"
        let modelManager = MLXModelManager()
        let catalogService = makeCatalogService(manager: modelManager, repoID: repoID)
        modelManager.localModels = [repoID]

        let warmer = MLXWarmupSpy()
        let coordinator = WarmupCoordinator(
            whisperTranscriber: Transcriber(modelName: "small"),
            parakeetTranscriber: ParakeetTranscriber(),
            mlxCatalogService: catalogService,
            mlxDownloadWarmupGate: MLXDownloadWarmupGate(cooldownInterval: 1),
            configProvider: { AppConfig() },
            mlxWarmer: { repoID in
                await warmer.record(repoID: repoID)
            }
        )

        var config = AppConfig()
        config.llmProvider = "mlx"
        config.mlxModel = repoID
        config.selectedDictationTemplate = .askAI

        coordinator.warmSelectedLLM(config: config)
        try? await Task.sleep(for: .milliseconds(20))

        let calledRepoIDs = await warmer.calledRepoIDs()

        XCTAssertEqual(calledRepoIDs, [repoID])
        XCTAssertEqual(coordinator.llmStatus, .ready(repoID))
    }
}

private extension WarmupCoordinatorTests {
    func makeCatalogService(
        manager: MLXModelManager,
        repoID: String
    ) -> MLXCatalogService {
        MLXCatalogService(
            manager: manager,
            hardwareClass: .compact,
            manifestLoader: {
                MLXCatalogValidationResult(
                    entries: [
                        MLXCatalogEntry(
                            id: "qwen3-4b-4bit",
                            repoID: repoID,
                            displayName: "Qwen 3 4B",
                            family: .qwen,
                            summary: "Compacto",
                            quantizationLabel: "4-bit",
                            estimatedDownloadSize: "~2.6 GB",
                            minimumUnifiedMemoryGB: 8,
                            recommendedHardwareClasses: [.compact],
                            selectionPriority: 10,
                            isRecommended: true,
                            runtimeKind: .llm,
                            legacyAliases: [],
                            replacementID: nil
                        )
                    ],
                    warnings: [],
                    usedFallback: false
                )
            }
        )
    }
}

private actor MLXWarmupSpy {
    private var repoIDs: [String] = []

    func record(repoID: String) {
        repoIDs.append(repoID)
    }

    func calledRepoIDs() -> [String] {
        repoIDs
    }
}
