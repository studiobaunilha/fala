import XCTest
@testable import FalaCore

@MainActor
final class StatusBarControllerTests: XCTestCase {
    func testPreparingStateUsesNonDownloadSymbol() {
        let controller = makeController()

        controller.setLoadingTooltip("Preparando Qwen 3 4B…")

        XCTAssertEqual(controller.currentSymbolNameForTesting, "clock.arrow.circlepath")
        XCTAssertEqual(controller.currentTooltipForTesting, "Preparando Qwen 3 4B…")
    }

    func testDownloadProgressOverridesPreparingTooltipUntilDownloadEnds() {
        let controller = makeController()

        controller.setLoadingTooltip("Preparando Qwen 3 4B…")
        controller.setDownloadProgress(0.42, modelName: "Qwen 3 4B")

        XCTAssertEqual(controller.currentSymbolNameForTesting, "arrow.down.circle")
        XCTAssertEqual(controller.currentTooltipForTesting, "Baixando Qwen 3 4B… 42%")

        controller.clearDownloadProgress()

        XCTAssertEqual(controller.currentSymbolNameForTesting, "clock.arrow.circlepath")
        XCTAssertEqual(controller.currentTooltipForTesting, "Preparando Qwen 3 4B…")
    }

    private func makeController() -> StatusBarController {
        let config = AppConfig()
        let settings = AppSettings(
            config: config,
            transcriber: Transcriber(modelName: config.dictationModel),
            modelManager: ModelManager()
        )

        return StatusBarController(
            settings: settings,
            onSettings: {},
            onTranscribe: {}
        )
    }
}
