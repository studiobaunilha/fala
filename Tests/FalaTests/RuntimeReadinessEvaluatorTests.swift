import XCTest
@testable import FalaCore

@MainActor
final class RuntimeReadinessEvaluatorTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AppLocalization.apply(languageCode: "pt-BR")
    }

    override func tearDown() {
        AppLocalization.apply(languageCode: "auto")
        super.tearDown()
    }

    func testLocalDictationReadinessDoesNotRequireActivation() {
        var config = AppConfig()
        config.transcriptionEngine = "parakeet"
        config.selectedDictationTemplate = .raw
        let settings = AppSettings(
            config: config,
            transcriber: Transcriber(modelName: config.dictationModel),
            modelManager: ModelManager(),
            permissionProvider: ReadinessPermissionProvider()
        )

        XCTAssertTrue(settings.readiness.issuesForDictation().isEmpty)
    }

    func testLocalFilesAndFirstRunDoNotRequireActivation() throws {
        var config = AppConfig()
        config.transcriptionEngine = "parakeet"
        config.selectedDictationTemplate = .raw
        let permissions = ReadinessPermissionProvider()
        let settings = AppSettings(
            config: config,
            transcriber: Transcriber(modelName: config.dictationModel),
            modelManager: ModelManager(),
            permissionProvider: permissions
        )
        let suite = "FreeFirstRun.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let onboarding = OnboardingViewModel(
            settings: settings,
            readiness: settings.readiness,
            permissionProvider: permissions,
            defaults: defaults
        )

        XCTAssertTrue(settings.readiness.issuesForBatch(batchPrompt: "").isEmpty)
        XCTAssertTrue(onboarding.isReadyToContinue)
        XCTAssertEqual(onboarding.steps.map(\.id), ["microphone", "accessibility", "engine", "llm"])
    }

    func testFreeDictationStillRequiresSystemPermissions() {
        var config = AppConfig()
        config.transcriptionEngine = "parakeet"
        config.selectedDictationTemplate = .raw
        let permissions = ReadinessPermissionProvider()
        permissions.microphoneState = .denied
        permissions.accessibilityTrusted = false
        let settings = AppSettings(
            config: config,
            transcriber: Transcriber(modelName: config.dictationModel),
            modelManager: ModelManager(),
            permissionProvider: permissions
        )

        let issues = settings.readiness.issuesForDictation()
        XCTAssertTrue(issues.contains { $0.kind == .microphonePermission && $0.blocking })
        XCTAssertTrue(issues.contains { $0.kind == .accessibilityPermission && $0.blocking })
    }

    func testUnsupportedMLXSelectionBlocksLLMMode() {
        var config = AppConfig()
        config.selectedDictationTemplate = .askAI
        config.llmProvider = "mlx"
        config.mlxModel = "mlx-community/Qwen3.5-4B-MLX-4bit"

        let settings = AppSettings(
            config: config,
            transcriber: Transcriber(modelName: config.dictationModel),
            modelManager: ModelManager(),
            permissionProvider: ReadinessPermissionProvider()
        )

        let issues = settings.readiness.issuesForDictation()

        XCTAssertTrue(issues.contains {
            $0.kind == .mlxModelMissing && $0.title == "Modelo MLX incompatível"
        })
    }

    func testIncompleteMLXSelectionBlocksLLMMode() throws {
        let repoID = "mlx-community/fala-test-incomplete-\(UUID().uuidString)"
        let directory = MLXModelManager.modelDir(for: repoID)
        try createDirectory(at: directory)
        defer { try? FileManager.default.removeItem(at: directory) }

        try "{}".write(
            to: directory.appendingPathComponent("config.json"),
            atomically: true,
            encoding: .utf8
        )

        var config = AppConfig()
        config.selectedDictationTemplate = .askAI
        config.llmProvider = "mlx"
        config.mlxModel = repoID

        let mlxModelManager = MLXModelManager()
        let catalogService = makeCatalogService(manager: mlxModelManager, repoID: repoID)
        let settings = AppSettings(
            config: config,
            transcriber: Transcriber(modelName: config.dictationModel),
            modelManager: ModelManager(),
            mlxModelManager: mlxModelManager,
            permissionProvider: ReadinessPermissionProvider()
        )
        let warmupCoordinator = WarmupCoordinator(
            whisperTranscriber: Transcriber(modelName: "small"),
            parakeetTranscriber: ParakeetTranscriber(),
            mlxCatalogService: catalogService,
            configProvider: { settings.snapshotConfig() }
        )
        let evaluator = RuntimeReadinessEvaluator(
            settings: settings,
            modelManager: settings.modelManager,
            mlxCatalogService: catalogService,
            permissionProvider: ReadinessPermissionProvider(),
            warmupCoordinator: warmupCoordinator
        )

        let issues = evaluator.issuesForDictation()

        XCTAssertTrue(issues.contains {
            $0.kind == .mlxModelMissing && $0.title == "Modelo MLX necessário"
        })
    }

    func testQuickMenuKeepsCustomVisibleWhenLLMIsNotReady() {
        var config = AppConfig()
        config.llmProvider = "gemini"
        config.geminiKey = ""

        let settings = AppSettings(
            config: config,
            transcriber: Transcriber(modelName: config.dictationModel),
            modelManager: ModelManager(),
            permissionProvider: ReadinessPermissionProvider()
        )

        let modes = settings.readiness.quickMenuModes()

        XCTAssertTrue(modes.contains(.raw))
        XCTAssertTrue(modes.contains(.custom))
        XCTAssertFalse(modes.contains(.askAI))
    }

    func testSelectionCommandUsesOnlyActiveProviderReadiness() {
        var config = AppConfig()
        config.llmProvider = "openai"
        config.openAIKey = "test-key"
        config.geminiKey = ""

        let settings = AppSettings(
            config: config,
            transcriber: Transcriber(modelName: config.dictationModel),
            modelManager: ModelManager(),
            permissionProvider: ReadinessPermissionProvider()
        )

        let issues = settings.readiness.issuesForSelectionCommand()

        XCTAssertTrue(issues.isEmpty)
    }

    func testSelectionCommandReportsMissingCloudKeyForActiveProvider() {
        var config = AppConfig()
        config.llmProvider = "gemini"
        config.geminiKey = ""

        let settings = AppSettings(
            config: config,
            transcriber: Transcriber(modelName: config.dictationModel),
            modelManager: ModelManager(),
            permissionProvider: ReadinessPermissionProvider()
        )

        let issues = settings.readiness.issuesForSelectionCommand()

        XCTAssertTrue(issues.contains {
            $0.kind == .cloudAPIKeyMissing && $0.title == "Chave Gemini necessária"
        })
    }
}

@MainActor
private final class ReadinessPermissionProvider: SystemPermissionProviding {
    var microphoneState: MicrophonePermissionState = .granted
    var accessibilityTrusted = true

    func microphonePermissionState() -> MicrophonePermissionState {
        microphoneState
    }

    func requestMicrophoneAccess() async -> Bool {
        true
    }

    func isAccessibilityTrusted() -> Bool {
        accessibilityTrusted
    }

    func openMicrophoneSettings() {}

    func openAccessibilitySettings() {}
}

private extension RuntimeReadinessEvaluatorTests {
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
                            id: "fala-test-incomplete",
                            repoID: repoID,
                            displayName: "Fala Test Incomplete",
                            family: .qwen,
                            summary: "Teste",
                            quantizationLabel: "4-bit",
                            estimatedDownloadSize: "~2.6 GB",
                            minimumUnifiedMemoryGB: 8,
                            recommendedHardwareClasses: [.compact],
                            selectionPriority: 10,
                            isRecommended: false,
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

    func createDirectory(at url: URL) throws {
        try? FileManager.default.removeItem(at: url)
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
    }
}
