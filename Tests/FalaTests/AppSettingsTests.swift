import XCTest
@testable import FalaCore

final class AppSettingsTests: XCTestCase {

    // swiftlint:disable:next implicitly_unwrapped_optional
    private var testConfigURL: URL!

    override func setUp() async throws {
        AppLocalization.apply(languageCode: "pt-BR")
        await MainActor.run { AnimationConfig.enabled = false }
        
        // Use a dedicated URL for testing to avoid polluting actual user config
        testConfigURL = FileManager.default.temporaryDirectory.appendingPathComponent("fala_test_config.json")
        try? FileManager.default.removeItem(at: testConfigURL)
    }
    
    override func tearDown() {
        AppLocalization.apply(languageCode: "auto")
        try? FileManager.default.removeItem(at: testConfigURL)
        super.tearDown()
    }

    @MainActor
    func testInitFromConfig() {
        var config = AppConfig()
        config.appLanguage = "en"
        config.dictationModel = "small"
        config.batchModel = "medium"
        config.transcriptionLanguage = "es"

        let transcriber = Transcriber(modelName: config.activeWhisperModel)
        let modelManager = ModelManager()

        let settings = AppSettings(
            config: config,
            transcriber: transcriber,
            modelManager: modelManager
        )

        XCTAssertEqual(settings.appLanguage, "en")
        XCTAssertEqual(settings.activeWhisperModel, "medium")
        XCTAssertEqual(settings.dictationModel, "medium")
        XCTAssertEqual(settings.batchModel, "medium")
        XCTAssertEqual(settings.transcriptionLanguage, "es")
    }

    @MainActor
    func testActiveWhisperModelUpdatesBothSelections() {
        var config = AppConfig()
        config.dictationModel = "small"
        config.batchModel = "small"
        let transcriber = Transcriber(modelName: "small")
        let modelManager = ModelManager()

        let settings = AppSettings(
            config: config,
            transcriber: transcriber,
            modelManager: modelManager
        )

        settings.activeWhisperModel = "medium"

        XCTAssertEqual(settings.activeWhisperModel, "medium")
        XCTAssertEqual(settings.dictationModel, "medium")
        XCTAssertEqual(settings.batchModel, "medium")
    }

    @MainActor
    func testActiveModelDownloadPrefersSelectedWhisperModel() {
        var config = AppConfig()
        config.dictationModel = "small"
        config.batchModel = "small"

        let settings = AppSettings(
            config: config,
            transcriber: Transcriber(modelName: config.activeWhisperModel),
            modelManager: ModelManager()
        )

        let activeDownload = settings.activeModelDownload(
            whisperDownloads: [
                "medium": 0.3,
                "small": 0.6
            ],
            mlxDownloads: [:]
        )

        XCTAssertEqual(activeDownload?.modelName, "Small")
        XCTAssertEqual(activeDownload?.fraction, 0.6)
    }

    @MainActor
    func testActiveModelDownloadUsesCuratedMLXLabel() {
        var config = AppConfig()
        config.llmProvider = "mlx"
        config.mlxModel = AppConfig.defaultMLXModelRepoID

        let settings = AppSettings(
            config: config,
            transcriber: Transcriber(modelName: config.activeWhisperModel),
            modelManager: ModelManager()
        )

        let activeDownload = settings.activeModelDownload(
            whisperDownloads: [:],
            mlxDownloads: [AppConfig.defaultMLXModelRepoID: 0.42]
        )

        XCTAssertEqual(activeDownload?.modelName, "Qwen 3 4B")
        XCTAssertEqual(activeDownload?.fraction, 0.42)
    }

    @MainActor
    func testInitMigratesDeprecatedQwenSelectionToCuratedDefault() {
        var config = AppConfig()
        config.llmProvider = "mlx"
        config.mlxModel = "mlx-community/Qwen2.5-3B-Instruct-4bit"

        let settings = AppSettings(
            config: config,
            transcriber: Transcriber(modelName: config.activeWhisperModel),
            modelManager: ModelManager()
        )

        XCTAssertEqual(settings.mlxModel, AppConfig.defaultMLXModelRepoID)
        XCTAssertEqual(settings.mlxCatalogMigrationNotice?.title, "Catálogo MLX atualizado")
        XCTAssertTrue(
            settings.mlxCatalogMigrationNotice?.message.contains("Qwen 3 4B") == true
        )
    }

    @MainActor
    func testSelectWhisperModelAfterDownloadUpdatesActiveSelection() {
        var config = AppConfig()
        config.dictationModel = "small"
        config.batchModel = "small"

        let settings = AppSettings(
            config: config,
            transcriber: Transcriber(modelName: config.activeWhisperModel),
            modelManager: ModelManager()
        )

        settings.selectWhisperModelAfterDownload("medium")

        XCTAssertEqual(settings.activeWhisperModel, "medium")
        XCTAssertEqual(settings.dictationModel, "medium")
        XCTAssertEqual(settings.batchModel, "medium")
        XCTAssertEqual(settings.snapshotConfig().activeWhisperModel, "medium")
    }

    @MainActor
    func testSelectMLXModelAfterDownloadUpdatesSelectedRepo() {
        let config = AppConfig()

        let settings = AppSettings(
            config: config,
            transcriber: Transcriber(modelName: config.activeWhisperModel),
            modelManager: ModelManager()
        )

        settings.selectMLXModelAfterDownload("mlx-community/gemma-3-text-4b-it-4bit")

        XCTAssertEqual(settings.mlxModel, "mlx-community/gemma-3-text-4b-it-4bit")
        XCTAssertEqual(
            settings.snapshotConfig().mlxModel,
            "mlx-community/gemma-3-text-4b-it-4bit"
        )
    }

    @MainActor
    func testAddReplacementRuleUsesUnifiedVocabularyRules() {
        let settings = AppSettings(
            config: AppConfig(),
            transcriber: Transcriber(modelName: AppConfig().activeWhisperModel),
            modelManager: ModelManager()
        )

        let didChange = settings.addReplacementRule(
            variant: "git hub",
            replacement: "GitHub"
        )

        XCTAssertTrue(didChange)
        XCTAssertEqual(settings.replacementRules.count, 1)
        XCTAssertEqual(settings.replacementRules[0].variants, ["git hub"])
        XCTAssertEqual(settings.replacementRules[0].replacement, "GitHub")
    }

    @MainActor
    func testRemoveReplacementVariantDeletesRuleWhenLastVariantIsRemoved() {
        var config = AppConfig()
        let rule = ReplacementRule(variants: ["jirah"], replacement: "JIRA")
        config.replacementRules = [rule]

        let settings = AppSettings(
            config: config,
            transcriber: Transcriber(modelName: config.activeWhisperModel),
            modelManager: ModelManager()
        )

        let didChange = settings.removeReplacementVariant("JIRAH", fromRuleID: rule.id)

        XCTAssertTrue(didChange)
        XCTAssertTrue(settings.replacementRules.isEmpty)
    }

    @MainActor
    func testAddParakeetVocabularyTermUsesNormalizedDedicatedStore() {
        let settings = AppSettings(
            config: AppConfig(),
            transcriber: Transcriber(modelName: AppConfig().activeWhisperModel),
            modelManager: ModelManager()
        )

        let didChange = settings.addParakeetVocabularyTerm(text: " OpenAI ")
        let duplicate = settings.addParakeetVocabularyTerm(text: "openai")

        XCTAssertTrue(didChange)
        XCTAssertFalse(duplicate)
        XCTAssertEqual(settings.parakeetVocabularyTerms, [ParakeetVocabularyTerm(text: "OpenAI")])
    }

    @MainActor
    func testRemoveParakeetVocabularyTermDeletesMatchingTextCaseInsensitively() {
        var config = AppConfig()
        config.parakeetVocabularyTerms = [ParakeetVocabularyTerm(text: "OpenAI")]

        let settings = AppSettings(
            config: config,
            transcriber: Transcriber(modelName: config.activeWhisperModel),
            modelManager: ModelManager()
        )

        let didChange = settings.removeParakeetVocabularyTerm(text: " openai ")

        XCTAssertTrue(didChange)
        XCTAssertTrue(settings.parakeetVocabularyTerms.isEmpty)
    }

    @MainActor
    func testVisibleDictationTemplatesHideAskAIButKeepCustomVisible() {
        let settings = AppSettings(
            config: AppConfig(),
            transcriber: Transcriber(modelName: AppConfig().activeWhisperModel),
            modelManager: ModelManager()
        )

        XCTAssertTrue(settings.visibleDictationTemplates.contains(.raw))
        XCTAssertTrue(settings.visibleDictationTemplates.contains(.custom))
        XCTAssertFalse(settings.visibleDictationTemplates.contains(.askAI))
    }
}
