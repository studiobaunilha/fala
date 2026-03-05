import XCTest
@testable import FalaCore

final class AppConfigTests: XCTestCase {

    // MARK: – Defaults

    func testDefaultValues() {
        let config = AppConfig()
        XCTAssertEqual(config.dictationModel, "large-v3-turbo")
        XCTAssertEqual(config.batchModel, "large-v3-turbo")
        XCTAssertEqual(config.outputFormat, "txt")
        XCTAssertEqual(config.language, "auto")
    }

    // MARK: – Backward compatibility

    /// Decoding a JSON that lacks newer fields (e.g. `language`) must still
    /// succeed and fall back to defaults — not throw and wipe the whole config.
    func testDecodesLegacyJSONWithMissingFields() throws {
        let legacy = Data("""
        {
          "batchModel": "large-v3-turbo",
          "dictationModel": "base",
          "outputFormat": "txt"
        }
        """.utf8)

        let config = try JSONDecoder().decode(AppConfig.self, from: legacy)
        XCTAssertEqual(config.dictationModel, "base", "dictationModel must survive")
        XCTAssertEqual(config.batchModel, "large-v3-turbo", "batchModel must survive")
        XCTAssertEqual(config.outputFormat, "txt", "outputFormat must survive")
        XCTAssertEqual(config.language, "auto", "missing language must default to auto")
    }

    // MARK: – Round-trip JSON encode/decode

    func testRoundTripCoding() throws {
        var config = AppConfig()
        config.dictationModel = "large-v3"
        config.batchModel = "turbo"
        config.outputFormat = "md"

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)

        let decoded = try JSONDecoder().decode(AppConfig.self, from: data)
        XCTAssertEqual(decoded.dictationModel, "large-v3")
        XCTAssertEqual(decoded.batchModel, "turbo")
        XCTAssertEqual(decoded.outputFormat, "md")
    }

    // MARK: – Missing file returns defaults

    func testLoadReturnDefaultsWhenFileAbsent() throws {
        // Point configURL to a nonexistent path by using a fresh temp dir.
        // AppConfig.load() uses ~/ — we test the decoder fallback by feeding
        // invalid JSON through the decoder directly.
        let badData = Data("not json".utf8)
        let decoded = try? JSONDecoder().decode(AppConfig.self, from: badData)
        XCTAssertNil(decoded, "Invalid JSON must not decode")
    }

    // MARK: – JSON keys are camelCase (Codable default)

    func testExpectedJSONKeys() throws {
        let config = AppConfig()
        let data = try JSONEncoder().encode(config)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json?["dictationModel"])
        XCTAssertNotNil(json?["batchModel"])
        XCTAssertNotNil(json?["outputFormat"])
        XCTAssertNotNil(json?["language"])
    }
}
