import XCTest
@testable import FalaCore

@MainActor
final class MLXModelManagerTests: XCTestCase {
    func testConfigOnlyDirectoryIsNotConsideredDownloaded() throws {
        let repoID = "mlx-community/fala-test-config-only-\(UUID().uuidString)"
        let directory = MLXModelManager.modelDir(for: repoID)
        try createDirectory(at: directory)
        defer { try? FileManager.default.removeItem(at: directory) }

        try "{}".write(
            to: directory.appendingPathComponent("config.json"),
            atomically: true,
            encoding: .utf8
        )

        XCTAssertFalse(MLXModelManager.isRepoDownloaded(repoID))
        XCTAssertFalse(MLXModelManager.isUsableModelDirectory(directory))
    }

    func testDirectoryWithConfigAndWeightsIsConsideredDownloaded() throws {
        let repoID = "mlx-community/fala-test-complete-\(UUID().uuidString)"
        let directory = MLXModelManager.modelDir(for: repoID)
        try createDirectory(at: directory)
        defer { try? FileManager.default.removeItem(at: directory) }

        try "{}".write(
            to: directory.appendingPathComponent("config.json"),
            atomically: true,
            encoding: .utf8
        )
        FileManager.default.createFile(
            atPath: directory.appendingPathComponent("model.safetensors").path,
            contents: Data("weights".utf8)
        )

        XCTAssertTrue(MLXModelManager.isRepoDownloaded(repoID))
        XCTAssertTrue(MLXModelManager.isUsableModelDirectory(directory))
    }
}

private extension MLXModelManagerTests {
    func createDirectory(at url: URL) throws {
        try? FileManager.default.removeItem(at: url)
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
    }
}
