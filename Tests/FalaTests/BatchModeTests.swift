import XCTest
@testable import FalaCore

final class BatchModeTests: XCTestCase {

    func testParseOptionsKeepsDefaultsWhenFlagsAreAbsent() {
        var config = AppConfig()
        config.outputFormat = "md"
        config.batchModel = "medium"
        config.selectedDictationTemplate = .translate

        let options = BatchMode.parseOptions(["audio.wav"], config: config)

        XCTAssertEqual(options.format, "md")
        XCTAssertEqual(options.model, config.activeWhisperModel)
        XCTAssertEqual(options.template, .translate)
        XCTAssertFalse(options.profile)
        XCTAssertFalse(options.prepareOnly)
    }

    func testParseOptionsRecognizesProfileAndOverrides() {
        let options = BatchMode.parseOptions(
            [
                "audio.m4a",
                "--format", "txt",
                "--model", "large-v3-turbo",
                "--mode", "Personalizado",
                "--profile",
                "--prepare-only"
            ],
            config: AppConfig()
        )

        XCTAssertEqual(options.format, "txt")
        XCTAssertEqual(options.model, "large-v3-turbo")
        XCTAssertEqual(options.template, .custom)
        XCTAssertTrue(options.profile)
        XCTAssertTrue(options.prepareOnly)
    }
}
