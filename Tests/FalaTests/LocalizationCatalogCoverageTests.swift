import Foundation
import XCTest

final class LocalizationCatalogCoverageTests: XCTestCase {
    func testEveryL10nKeyUsedInSourcesExistsInStringCatalog() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceRoot = repoRoot.appendingPathComponent("Sources/FalaCore")
        let catalogURL = sourceRoot.appendingPathComponent("Resources/Localizable.xcstrings")

        let catalogData = try Data(contentsOf: catalogURL)
        let catalog = try JSONDecoder().decode(StringCatalog.self, from: catalogData)
        let catalogKeys = Set(catalog.strings.keys)

        let regex = try NSRegularExpression(pattern: #"L10n\("((?:[^"\\]|\\.)*)"\)"#)
        var usedKeys = Set<String>()

        let enumerator = FileManager.default.enumerator(
            at: sourceRoot,
            includingPropertiesForKeys: nil
        )

        while let fileURL = enumerator?.nextObject() as? URL {
            guard fileURL.pathExtension == "swift" else { continue }
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            let range = NSRange(source.startIndex..<source.endIndex, in: source)

            for match in regex.matches(in: source, range: range) {
                guard match.numberOfRanges > 1,
                      let rawRange = Range(match.range(at: 1), in: source)
                else {
                    continue
                }

                let rawLiteral = String(source[rawRange])
                let decoded = try decodeSwiftStringLiteral(rawLiteral)
                usedKeys.insert(decoded)
            }
        }

        let missing = usedKeys.subtracting(catalogKeys).sorted()
        XCTAssertTrue(
            missing.isEmpty,
            "Missing \(missing.count) L10n keys in Localizable.xcstrings:\n\(missing.joined(separator: "\n"))"
        )
    }

    private func decodeSwiftStringLiteral(_ rawLiteral: String) throws -> String {
        let data = Data(("\"" + rawLiteral + "\"").utf8)
        return try JSONDecoder().decode(String.self, from: data)
    }
}

private struct StringCatalog: Decodable {
    let strings: [String: StringCatalogEntry]
}

private struct StringCatalogEntry: Decodable {}
