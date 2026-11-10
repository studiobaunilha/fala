import XCTest
@testable import FalaCore

final class AppConfigMigrationTests: XCTestCase {
    func testNewConfigPersistsUltraAsParakeetDefault() throws {
        let data = try JSONEncoder().encode(AppConfig())
        let values = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(values["parakeetModel"] as? String, "ultra")
    }

    func testExplicitV3SurvivesSaveAndReloadWithoutChangingWhisperChoice() throws {
        let payload = Data(#"{"transcriptionEngine":"whisper","parakeetModel":"v3"}"#.utf8)
        let decoded = try JSONDecoder().decode(AppConfig.self, from: payload)
        let reloaded = try JSONDecoder().decode(AppConfig.self, from: JSONEncoder().encode(decoded))

        XCTAssertEqual(reloaded.transcriptionEngine, "whisper")
        XCTAssertEqual(reloaded.parakeetModel, .v3)
    }

    func testMissingOrInvalidParakeetChoiceUsesUltraWithoutChangingOtherSettings() throws {
        for payload in [#"{"transcriptionEngine":"whisper"}"#,
                        #"{"transcriptionEngine":"whisper","parakeetModel":"unknown"}"#] {
            let config = try JSONDecoder().decode(AppConfig.self, from: Data(payload.utf8))
            XCTAssertEqual(config.parakeetModel, .ultra)
            XCTAssertEqual(config.transcriptionEngine, "whisper")
        }
    }

    func testDecodesLegacySelectionPasteDirectlyIntoAIResultToggle() throws {
        let legacy = Data("""
        {
          "selectionPasteDirectly": false
        }
        """.utf8)

        let config = try JSONDecoder().decode(AppConfig.self, from: legacy)

        XCTAssertTrue(config.plainDictationPasteDirectly)
        XCTAssertFalse(config.aiResultPasteDirectly)
        XCTAssertFalse(config.selectionPasteDirectly)
    }
}
