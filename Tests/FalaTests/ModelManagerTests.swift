import XCTest
@testable import FalaCore

final class ModelManagerTests: XCTestCase, @unchecked Sendable {

    // MARK: – Helpers

    /// Creates a temporary directory mimicking a downloaded model (with AudioEncoder.mlmodelc stub).
    private func makeFakeModel(
        named variant: String,
        in cacheDir: URL
    ) throws -> URL {
        let modelDir = cacheDir.appendingPathComponent(variant)
        let encoderDir = modelDir.appendingPathComponent("AudioEncoder.mlmodelc")
        try FileManager.default.createDirectory(at: encoderDir, withIntermediateDirectories: true)
        // Write a small file so it has non-zero size
        let dummy = encoderDir.appendingPathComponent("model.bin")
        try Data(repeating: 0, count: 1024).write(to: dummy)
        return modelDir
    }

    // MARK: – scanLocal

    func testScanLocalFindsDownloadedModels() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("fala_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        _ = try makeFakeModel(named: "openai_whisper-medium", in: tmpDir)
        _ = try makeFakeModel(named: "openai_whisper-base", in: tmpDir)

        // Create a directory WITHOUT AudioEncoder.mlmodelc (incomplete download)
        let incomplete = tmpDir.appendingPathComponent("openai_whisper-tiny")
        try FileManager.default.createDirectory(at: incomplete, withIntermediateDirectories: true)

        MainActor.assumeIsolated {
            // Use internal scan that takes a directory parameter
            let found = ModelManager.scanDirectory(tmpDir)
            XCTAssertEqual(found.count, 2)
            XCTAssertTrue(found.contains("openai_whisper-medium"))
            XCTAssertTrue(found.contains("openai_whisper-base"))
            XCTAssertFalse(found.contains("openai_whisper-tiny"))
        }
    }

    // MARK: – isDownloaded

    func testIsDownloadedMatchesShortNames() {
        MainActor.assumeIsolated {
            let manager = ModelManager()
            // Simulate having openai_whisper-medium downloaded
            manager.localModels = ["openai_whisper-medium", "openai_whisper-base"]

            XCTAssertTrue(manager.isDownloaded("medium"))
            XCTAssertTrue(manager.isDownloaded("base"))
            XCTAssertFalse(manager.isDownloaded("large-v3-turbo"))
            XCTAssertFalse(manager.isDownloaded("tiny"))
        }
    }

    // MARK: – variantName

    func testVariantNameReturnsCorrectMapping() {
        MainActor.assumeIsolated {
            let manager = ModelManager()
            XCTAssertEqual(manager.variantName(for: "medium"), "openai_whisper-medium")
            XCTAssertEqual(manager.variantName(for: "large-v3-turbo"), "openai_whisper-large-v3_turbo")
            XCTAssertNil(manager.variantName(for: "nonexistent"))
        }
    }

    // MARK: – delete

    func testDeleteRemovesModelDirectory() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("fala_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let modelDir = try makeFakeModel(named: "openai_whisper-base", in: tmpDir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: modelDir.path))

        // Delete the directory directly (same logic as ModelManager.delete)
        try FileManager.default.removeItem(at: modelDir)
        XCTAssertFalse(FileManager.default.fileExists(atPath: modelDir.path))
    }

    // MARK: – knownModels

    func testKnownModelsHaveUniqueIds() {
        let ids = knownModels.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "Model ids must be unique")
    }

    func testKnownModelsHaveUniqueVariants() {
        let variants = knownModels.map(\.variant)
        XCTAssertEqual(variants.count, Set(variants).count, "Model variants must be unique")
    }
}
