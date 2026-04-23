import XCTest
@testable import FalaCore

final class AppConfigMigrationTests: XCTestCase {
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
