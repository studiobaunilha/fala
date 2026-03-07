import AppKit
import XCTest
@testable import FalaCore

@MainActor
final class LocalizationRuntimeReloadTests: XCTestCase {
    override func setUp() async throws {
        AppLocalization.apply(languageCode: "pt-BR")
    }

    override func tearDown() async throws {
        AppLocalization.apply(languageCode: "auto")
    }

    func testSettingsWindowControllerRehostsContentWhenLanguageChanges() {
        let settings = makeSettings()
        let controller = SettingsWindowController(settings: settings)

        controller.show()
        let originalContentView = controller.currentWindow?.contentView

        AppLocalization.apply(languageCode: "en")
        controller.reloadLocalizedContent()

        guard let originalContentView, let currentContentView = controller.currentWindow?.contentView else {
            return XCTFail("Settings window content should exist before and after reload")
        }

        XCTAssertEqual(controller.currentWindow?.title, "Settings")
        XCTAssertNotEqual(
            ObjectIdentifier(currentContentView),
            ObjectIdentifier(originalContentView)
        )
        controller.currentWindow?.orderOut(nil)
    }

    func testTranscribeWindowControllerRehostsContentWhenLanguageChanges() {
        let settings = makeSettings()
        let controller = TranscribeWindowController(settings: settings)

        controller.show()
        let originalContentView = controller.currentWindow?.contentView

        AppLocalization.apply(languageCode: "es")
        controller.reloadLocalizedContent()

        guard let originalContentView, let currentContentView = controller.currentWindow?.contentView else {
            return XCTFail("Transcribe window content should exist before and after reload")
        }

        XCTAssertEqual(
            controller.currentWindow?.title,
            AppLocalization.localizedString(for: "Transcrever Arquivo — Fala", languageCode: "es")
        )
        XCTAssertNotEqual(
            ObjectIdentifier(currentContentView),
            ObjectIdentifier(originalContentView)
        )
        controller.currentWindow?.orderOut(nil)
    }

    func testStatusBarControllerReloadsLocalizedMenuLabels() {
        let settings = makeSettings()
        let controller = StatusBarController(
            settings: settings,
            onSettings: {},
            onTranscribe: {}
        )

        XCTAssertEqual(controller.settingsItemTitleForTesting, "Ajustes…")

        AppLocalization.apply(languageCode: "en")
        controller.reloadLocalizedContent()

        XCTAssertEqual(controller.settingsItemTitleForTesting, "Settings…")
    }

    func testAppMainMenuInstallsLocalizedTitles() {
        let delegate = AppDelegate()

        AppLocalization.apply(languageCode: "en")
        AppMainMenu.install(appDelegate: delegate)

        let appMenu = NSApp.mainMenu?.item(at: 0)?.submenu
        let editMenu = NSApp.mainMenu?.item(at: 1)?.submenu

        XCTAssertEqual(appMenu?.item(at: 0)?.title, "Settings…")
        XCTAssertEqual(editMenu?.title, "Edit")
    }

    private func makeSettings() -> AppSettings {
        let config = AppConfig()
        let transcriber = Transcriber(
            modelName: config.dictationModel,
            language: config.transcriptionLanguage,
            temperature: config.dictationTemperature,
            prompt: ""
        )
        return AppSettings(
            config: config,
            transcriber: transcriber,
            modelManager: ModelManager()
        )
    }
}
