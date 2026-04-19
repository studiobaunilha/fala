import Foundation
import XCTest
@testable import FalaCore

final class MLXCatalogLocalizationTests: XCTestCase {
    func testEveryCatalogSummaryHasTranslationsForAllSupportedLanguages() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceRoot = repoRoot.appendingPathComponent("Sources/FalaCore")
        let catalogURL = sourceRoot.appendingPathComponent("Resources/Localizable.xcstrings")

        let catalogData = try Data(contentsOf: catalogURL)
        let catalog = try JSONDecoder().decode(StringCatalog.self, from: catalogData)

        let bundledEntries = MLXCatalogManifestLoader.load().entries
        let fallbackSummaries = MLXCatalogManifestLoader.fallbackEntries.map(\.summary)
        let allSummaries = Set(bundledEntries.map(\.summary) + fallbackSummaries)

        let requiredLanguages = AppLocalization.supportedAppLanguageCodes.filter { $0 != "pt-BR" }

        var missing: [String] = []
        for summary in allSummaries.sorted() {
            guard let entry = catalog.strings[summary] else {
                missing.append("[absent] \(summary)")
                continue
            }
            for lang in requiredLanguages {
                let value = entry.localizations[lang]?.stringUnit?.value ?? ""
                if value.isEmpty {
                    missing.append("[\(lang) empty] \(summary)")
                }
            }
        }

        XCTAssertTrue(
            missing.isEmpty,
            "MLX catalog summaries missing translations:\n\(missing.joined(separator: "\n"))"
        )
    }
}

private struct StringCatalog: Decodable {
    let strings: [String: StringCatalogEntry]
}

private struct StringCatalogEntry: Decodable {
    let localizations: [String: StringCatalogLocalization]
}

private struct StringCatalogLocalization: Decodable {
    let stringUnit: StringCatalogStringUnit?
}

private struct StringCatalogStringUnit: Decodable {
    let value: String
}
