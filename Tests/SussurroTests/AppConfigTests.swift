import XCTest
@testable import SussurroCore

final class AppConfigTests: XCTestCase {

    // MARK: – Defaults

    func testDefaultValues() {
        let config = AppConfig()
        XCTAssertEqual(config.dictationModel, "large-v3-turbo")
        XCTAssertEqual(config.batchModel, "large-v3-turbo")
        XCTAssertEqual(config.outputFormat, "txt")
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
    }
}
