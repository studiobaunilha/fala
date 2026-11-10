import XCTest
@testable import FalaCore

final class ParakeetModelSelectionTests: XCTestCase {
    func testVocabularyRequiresAcousticEvidenceUsingTheDocumentedDictationPreset() {
        let thresholds = DefaultParakeetRuntimeManager.vocabularyThresholds
        XCTAssertEqual(thresholds.cbw, 0)
        XCTAssertEqual(thresholds.minSimilarity, 0.7)
    }

    @MainActor
    func testConfirmedParakeetChangePersistsV3AndKeepsTheEngine() {
        let previousConfig = UserDefaults.standard.object(forKey: "dev.fala.config")
        defer {
            if let previousConfig {
                UserDefaults.standard.set(previousConfig, forKey: "dev.fala.config")
            } else {
                UserDefaults.standard.removeObject(forKey: "dev.fala.config")
            }
        }
        let prompt = ModelRestartPrompt(confirmed: true)
        let config = AppConfig()
        let settings = AppSettings(
            config: config,
            transcriber: Transcriber(modelName: config.activeWhisperModel),
            modelManager: ModelManager(),
            restartCoordinator: AppRestartCoordinator(
                promptPresenter: prompt,
                relauncher: ModelRelauncher(),
                terminationHandler: {}
            )
        )

        settings.requestParakeetModelChange(.v3)
        settings.requestParakeetModelChange(.v3)

        XCTAssertEqual(settings.parakeetModel, .v3)
        XCTAssertEqual(AppConfig.load().parakeetModel, .v3)
        XCTAssertEqual(settings.transcriptionEngine, "parakeet")
        XCTAssertEqual(prompt.calls, 1)
    }

    @MainActor
    func testCancelingParakeetChangePreservesCurrentModelAndEngine() {
        let prompt = ModelRestartPrompt(confirmed: false)
        let restart = AppRestartCoordinator(
            promptPresenter: prompt,
            relauncher: ModelRelauncher(),
            terminationHandler: {}
        )
        let config = AppConfig()
        let settings = AppSettings(
            config: config,
            transcriber: Transcriber(modelName: config.activeWhisperModel),
            modelManager: ModelManager(),
            restartCoordinator: restart
        )
        var refreshCount = 0
        let observation = settings.objectWillChange.sink { refreshCount += 1 }

        settings.requestParakeetModelChange(.v3)

        XCTAssertEqual(settings.parakeetModel, .ultra)
        XCTAssertEqual(settings.transcriptionEngine, "parakeet")
        XCTAssertEqual(prompt.calls, 1)
        XCTAssertEqual(refreshCount, 1, "The picker must refresh back to the unchanged selection after canceling")
        withExtendedLifetime(observation) {}
    }

    @MainActor
    func testSettingsSnapshotRetainsTheSelectedParakeetModel() {
        var config = AppConfig()
        config.parakeetModel = .v3
        let settings = AppSettings(
            config: config,
            transcriber: Transcriber(modelName: config.activeWhisperModel),
            modelManager: ModelManager()
        )

        XCTAssertEqual(settings.parakeetModel, .v3)
        settings.parakeetModel = .ultra
        XCTAssertEqual(settings.snapshotConfig().parakeetModel, .ultra)
    }
}

@MainActor
private final class ModelRestartPrompt: RestartPromptPresenting {
    let confirmed: Bool
    var calls = 0

    init(confirmed: Bool) { self.confirmed = confirmed }

    func confirmRestart(title: String, message: String, confirmTitle: String, cancelTitle: String) -> Bool {
        calls += 1
        return confirmed
    }
}

@MainActor
private final class ModelRelauncher: AppRelaunching {
    func relaunch(completion: @escaping @MainActor (AppRelaunchResult) -> Void) {
        completion(.launched)
    }
}
