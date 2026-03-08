import XCTest

final class MLXCatalogUISourceTests: XCTestCase {
    func testMLXSettingsNoLongerExposeFreeformRepoControls() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fileURL = repoRoot.appendingPathComponent("Sources/FalaCore/UI/SettingsView+LLMProviders.swift")
        let source = try String(contentsOf: fileURL, encoding: .utf8)

        XCTAssertFalse(source.contains("Repo ID customizado"))
        XCTAssertFalse(source.contains("Usar repo customizado"))
        XCTAssertFalse(source.contains("Sugestões"))
        XCTAssertFalse(source.contains("customRepoID"))
    }

    func testMLXSettingsObserveDedicatedCatalogObjects() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fileURL = repoRoot.appendingPathComponent("Sources/FalaCore/UI/SettingsView+LLMProviders.swift")
        let source = try String(contentsOf: fileURL, encoding: .utf8)

        XCTAssertTrue(source.contains("@ObservedObject private var modelManager: MLXModelManager"))
        XCTAssertTrue(source.contains("@ObservedObject private var catalogService: MLXCatalogService"))
        XCTAssertTrue(source.contains("modelManager.downloads"))
    }
}
