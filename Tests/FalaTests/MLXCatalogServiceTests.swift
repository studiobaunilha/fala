import XCTest
@testable import FalaCore

@MainActor
final class MLXCatalogServiceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AppLocalization.apply(languageCode: "pt-BR")
    }

    override func tearDown() {
        AppLocalization.apply(languageCode: "auto")
        super.tearDown()
    }

    func testSectionsFollowFamilyOrderAndHideLegacyByDefault() {
        let service = makeService(hardwareClass: .balanced)

        let families = service.sections().map(\.family)

        XCTAssertEqual(families, [.qwen, .gemma, .liquid])
    }

    func testLegacySectionAppearsWhenSelectedLegacyModel() {
        let service = makeService(hardwareClass: .balanced)

        let families = service.sections(
            selectedRepoID: "mlx-community/Llama-3.2-3B-Instruct-4bit"
        ).map(\.family)

        XCTAssertEqual(families, [.qwen, .gemma, .liquid, .legacy])
    }

    func testResolveSelectionMigratesDeprecatedQwenAlias() {
        let service = makeService(hardwareClass: .compact)

        let resolution = service.resolveSelection(repoID: "mlx-community/Qwen2.5-3B-Instruct-4bit")

        XCTAssertEqual(resolution.status, .migrated)
        XCTAssertEqual(resolution.resolvedRepoID, AppConfig.defaultMLXModelRepoID)
        XCTAssertEqual(resolution.entry?.displayName, "Qwen 3 4B")
    }

    func testNormalizeConfigPreservesSupportedLegacySelection() {
        let service = makeService(hardwareClass: .balanced)
        var config = AppConfig()
        config.mlxModel = "mlx-community/Meta-Llama-3.1-8B-Instruct-4bit"

        let normalization = service.normalize(config: config)

        XCTAssertFalse(normalization.didChange)
        XCTAssertEqual(normalization.config.mlxModel, "mlx-community/Meta-Llama-3.1-8B-Instruct-4bit")
        XCTAssertNil(normalization.migrationNotice)
    }

    func testNormalizeConfigMigratesDeprecatedSelection() {
        let service = makeService(hardwareClass: .compact)
        var config = AppConfig()
        config.mlxModel = "mlx-community/Qwen2.5-3B-Instruct-4bit"

        let normalization = service.normalize(config: config)

        XCTAssertTrue(normalization.didChange)
        XCTAssertEqual(normalization.config.mlxModel, AppConfig.defaultMLXModelRepoID)
        XCTAssertEqual(normalization.migrationNotice?.title, "Catálogo MLX atualizado")
    }

    func testCompactHardwareHighlightsCompactRecommendation() {
        let compactService = makeService(hardwareClass: .compact)
        let proService = makeService(hardwareClass: .pro)
        let qwen4B = try? XCTUnwrap(compactService.entry(for: AppConfig.defaultMLXModelRepoID))
        let qwen8B = try? XCTUnwrap(compactService.entry(for: "mlx-community/Qwen3-8B-4bit"))

        guard let qwen4B, let qwen8B else {
            return XCTFail("Expected curated Qwen entries")
        }

        XCTAssertEqual(qwen4B.displayName, "Qwen 3 4B")
        XCTAssertTrue(compactService.isIdealForCurrentMac(qwen4B))
        XCTAssertFalse(compactService.isIdealForCurrentMac(qwen8B))
        XCTAssertTrue(proService.isIdealForCurrentMac(qwen8B))
    }

    func testUnsupportedSelectionRemainsBlocked() {
        let service = makeService(hardwareClass: .balanced)

        let resolution = service.resolveSelection(repoID: "mlx-community/Qwen3.5-4B-MLX-4bit")

        XCTAssertEqual(resolution.status, .unsupported)
        XCTAssertNil(resolution.entry)
    }

    private func makeService(hardwareClass: MLXHardwareClass) -> MLXCatalogService {
        let manager = MLXModelManager()
        return MLXCatalogService(
            manager: manager,
            hardwareClass: hardwareClass,
            manifestLoader: { MLXCatalogManifestLoader.load() }
        )
    }
}
