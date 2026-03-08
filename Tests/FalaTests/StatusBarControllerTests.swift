import XCTest
@testable import FalaCore

@MainActor
final class StatusBarControllerTests: XCTestCase {
    func testInitialStateRendersIdleMicSymbol() {
        let controller = makeController()

        XCTAssertEqual(controller.currentSymbolNameForTesting, "mic")
        XCTAssertEqual(controller.imageAssignmentCountForTesting, 1)
    }

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

    func testDownloadProgressReusesCachedImageAcrossTooltipUpdates() throws {
        let controller = makeController()

        controller.setDownloadProgress(0.42, modelName: "Qwen 3 4B")
        let initialImageID = try XCTUnwrap(controller.currentImageObjectIdentifierForTesting)
        let imageAssignments = controller.imageAssignmentCountForTesting

        controller.setDownloadProgress(0.43, modelName: "Qwen 3 4B")

        XCTAssertEqual(
            controller.currentImageObjectIdentifierForTesting,
            initialImageID
        )
        XCTAssertEqual(controller.imageAssignmentCountForTesting, imageAssignments)
        XCTAssertEqual(controller.currentTooltipForTesting, "Baixando Qwen 3 4B… 43%")
    }

    func testDownloadProgressIgnoresRepeatedDisplayPercentUpdates() {
        let controller = makeController()

        controller.setDownloadProgress(0.421, modelName: "Qwen 3 4B")
        let renderCount = controller.renderCountForTesting

        controller.setDownloadProgress(0.429, modelName: "Qwen 3 4B")

        XCTAssertEqual(controller.renderCountForTesting, renderCount)
        XCTAssertEqual(controller.currentTooltipForTesting, "Baixando Qwen 3 4B… 42%")
    }

    func testLoadingTooltipReusesCachedImageAcrossMessageUpdates() throws {
        let controller = makeController()

        controller.setLoadingTooltip("Preparando Qwen 3 4B…")
        let initialImageID = try XCTUnwrap(controller.currentImageObjectIdentifierForTesting)
        let imageAssignments = controller.imageAssignmentCountForTesting

        controller.setLoadingTooltip("Preparando Gemma 3 4B…")

        XCTAssertEqual(
            controller.currentImageObjectIdentifierForTesting,
            initialImageID
        )
        XCTAssertEqual(controller.imageAssignmentCountForTesting, imageAssignments)
        XCTAssertEqual(controller.currentTooltipForTesting, "Preparando Gemma 3 4B…")
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
