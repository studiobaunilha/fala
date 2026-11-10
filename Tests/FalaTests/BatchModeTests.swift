import XCTest
@testable import FalaCore

final class BatchModeTests: XCTestCase {
    func testParakeetModelOverrideRejectsUnknownAndMissingNames() {
        for arguments in [["audio.wav", "--parakeet-model", "unknown"], ["audio.wav", "--parakeet-model"]] {
            XCTAssertThrowsError(try BatchMode.parseOptions(arguments, config: AppConfig())) { error in
                XCTAssertNotNil(error as? BatchError)
            }
        }
    }

    func testParakeetModelOverrideDoesNotChangeStoredConfiguration() throws {
        var config = AppConfig()
        config.parakeetModel = .ultra
        config.transcriptionEngine = "whisper"

        let options = try BatchMode.parseOptions(["audio.wav", "--parakeet-model", "v3"], config: config)

        XCTAssertEqual(options.parakeetModel, .v3)
        XCTAssertEqual(config.parakeetModel, .ultra)
        XCTAssertEqual(config.transcriptionEngine, "whisper")
    }

    func testParseOptionsKeepsDefaultsWhenFlagsAreAbsent() throws {
        var config = AppConfig()
        config.outputFormat = "md"
        config.batchModel = "medium"
        config.selectedDictationTemplate = .translate

        let options = try BatchMode.parseOptions(["audio.wav"], config: config)

        XCTAssertEqual(options.format, "md")
        XCTAssertEqual(options.model, config.activeWhisperModel)
        XCTAssertEqual(options.template, .translate)
        XCTAssertFalse(options.profile)
        XCTAssertFalse(options.prepareOnly)
    }

    func testParseOptionsRecognizesProfileAndOverrides() throws {
        let options = try BatchMode.parseOptions(
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
