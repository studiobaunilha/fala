import XCTest
@testable import FalaCore

final class MLXCatalogManifestLoaderTests: XCTestCase {
    func testBundledManifestLoadsCuratedCatalog() {
        let result = MLXCatalogManifestLoader.load()

        XCTAssertFalse(result.usedFallback)
        XCTAssertTrue(result.warnings.isEmpty)
        XCTAssertEqual(result.entries.first?.repoID, AppConfig.defaultMLXModelRepoID)
        XCTAssertTrue(result.entries.contains { $0.repoID == "mlx-community/gemma-3-text-4b-it-4bit" })
        XCTAssertTrue(result.entries.contains { $0.repoID == "mlx-community/LFM2-1.2B-4bit" })
    }

    func testManifestRejectsDuplicateRepoID() throws {
        let entry = try XCTUnwrap(MLXCatalogManifestLoader.load().entries.first)
        let duplicate = MLXCatalogEntry(
            id: "duplicate-id",
            repoID: entry.repoID,
            displayName: entry.displayName,
            family: entry.family,
            summary: entry.summary,
            quantizationLabel: entry.quantizationLabel,
            estimatedDownloadSize: entry.estimatedDownloadSize,
            minimumUnifiedMemoryGB: entry.minimumUnifiedMemoryGB,
            recommendedHardwareClasses: entry.recommendedHardwareClasses,
            selectionPriority: entry.selectionPriority + 1,
            isRecommended: false,
            runtimeKind: .llm,
            legacyAliases: [],
            replacementID: nil
        )
        let manifest = MLXCatalogManifest(entries: [entry, duplicate])

        XCTAssertThrowsError(try MLXCatalogManifestLoader.validate(manifest: manifest)) { error in
            XCTAssertEqual(error as? MLXCatalogValidationError, .duplicateRepoID(entry.repoID))
        }
    }

    func testManifestRejectsUnverifiedRecommendedEntry() {
        let manifestData = Data(
            """
            {
              "entries": [
                {
                  "id": "qwen3-8b-4bit",
                  "repoID": "mlx-community/Qwen3-8B-4bit",
                  "displayName": "Qwen 3 8B",
                  "family": "qwen",
                  "summary": "Teste",
                  "quantizationLabel": "4-bit",
                  "estimatedDownloadSize": "~5.2 GB",
                  "minimumUnifiedMemoryGB": 16,
                  "recommendedHardwareClasses": ["balanced", "pro"],
                  "selectionPriority": 10,
                  "isRecommended": true,
                  "runtimeKind": "llm",
                  "legacyAliases": [],
                  "replacementID": null
                }
              ]
            }
            """.utf8
        )

        XCTAssertThrowsError(try MLXCatalogManifestLoader.load(data: manifestData)) { error in
            XCTAssertEqual(
                error as? MLXCatalogValidationError,
                .unverifiedRecommended("mlx-community/Qwen3-8B-4bit")
            )
        }
    }

    func testManifestRejectsNonLLMRuntimeKind() {
        let manifestData = Data(
            """
            {
              "entries": [
                {
                  "id": "qwen3-vlm",
                  "repoID": "mlx-community/Qwen3.5-4B-MLX-4bit",
                  "displayName": "Qwen 3.5 4B",
                  "family": "qwen",
                  "summary": "Teste",
                  "quantizationLabel": "4-bit",
                  "estimatedDownloadSize": "~2.5 GB",
                  "minimumUnifiedMemoryGB": 8,
                  "recommendedHardwareClasses": ["compact"],
                  "selectionPriority": 10,
                  "isRecommended": false,
                  "runtimeKind": "vlm",
                  "legacyAliases": [],
                  "replacementID": null
                }
              ]
            }
            """.utf8
        )

        XCTAssertThrowsError(try MLXCatalogManifestLoader.load(data: manifestData))
    }

    func testManifestAcceptsGemmaTextFamilyAgainstCurrentRuntime() throws {
        let manifest = MLXCatalogManifest(
            entries: [
                MLXCatalogEntry(
                    id: "gemma3-text-4b-it-4bit",
                    repoID: "mlx-community/gemma-3-text-4b-it-4bit",
                    displayName: "Gemma 3 Text 4B",
                    family: .gemma,
                    summary: "Teste",
                    quantizationLabel: "4-bit",
                    estimatedDownloadSize: "~2.7 GB",
                    minimumUnifiedMemoryGB: 8,
                    recommendedHardwareClasses: [.compact, .balanced],
                    selectionPriority: 10,
                    isRecommended: true,
                    runtimeKind: .llm,
                    legacyAliases: [],
                    replacementID: nil
                )
            ]
        )

        let result = try MLXCatalogManifestLoader.validate(manifest: manifest)
        XCTAssertEqual(result.entries.map(\.repoID), ["mlx-community/gemma-3-text-4b-it-4bit"])
    }
}
