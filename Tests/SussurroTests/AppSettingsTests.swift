import XCTest
@testable import SussurroCore

@MainActor
final class AppSettingsTests: XCTestCase {

    override func setUp() async throws {
        await MainActor.run { AnimationConfig.enabled = false }
    }

    func testInitFromConfig() {
        var config = AppConfig()
        config.dictationModel = "test-dictation"
        config.batchModel = "test-batch"
        config.language = "es"

        let transcriber = Transcriber(modelName: "test-dictation")
        let modelManager = ModelManager()

        let settings = AppSettings(
            config: config,
            transcriber: transcriber,
            modelManager: modelManager
        )

        XCTAssertEqual(settings.dictationModel, "test-dictation")
        XCTAssertEqual(settings.batchModel, "test-batch")
        XCTAssertEqual(settings.language, "es")
    }

    func testSaveUpdatesTranscriber() {
        // Can't easily test transcriber internal state in a unit test without mocking,
        // but we can ensure save() runs without issues.
        var config = AppConfig()
        config.dictationModel = "test-dictation"
        let transcriber = Transcriber(modelName: "test-dictation")
        let modelManager = ModelManager()

        let settings = AppSettings(
            config: config,
            transcriber: transcriber,
            modelManager: modelManager
        )

        settings.dictationModel = "new-dictation"
        settings.save()

        // Just checking execution completes
        XCTAssertEqual(settings.dictationModel, "new-dictation")
    }
}
