import XCTest
@testable import FalaCore

final class MLXRuntimeSupportTests: XCTestCase {
    func testFindsMetallibInsideSwiftPMResourceBundle() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let appURL = tempDir.appendingPathComponent("Fala.app", isDirectory: true)
        let resourcesURL = appURL.appendingPathComponent("Contents/Resources", isDirectory: true)
        let metallibURL = resourcesURL
            .appendingPathComponent("mlx-swift_Cmlx.bundle", isDirectory: true)
            .appendingPathComponent("Contents/Resources/default.metallib")

        try FileManager.default.createDirectory(
            at: metallibURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        XCTAssertTrue(FileManager.default.createFile(atPath: metallibURL.path, contents: Data()))
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let resolved = MLXRuntimeSupport.defaultMetallibURL(
            mainBundleURL: appURL,
            bundleResourceURLs: [resourcesURL],
            frameworkResourceURLs: []
        )

        XCTAssertEqual(resolved?.standardizedFileURL, metallibURL.standardizedFileURL)
    }

    func testReturnsNilWhenMetallibIsMissing() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let resolved = MLXRuntimeSupport.defaultMetallibURL(
            mainBundleURL: tempDir,
            bundleResourceURLs: [],
            frameworkResourceURLs: []
        )

        XCTAssertNil(resolved)
    }
}
