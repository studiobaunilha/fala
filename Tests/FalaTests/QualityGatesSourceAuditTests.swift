import Foundation
import XCTest

final class QualityGatesSourceAuditTests: XCTestCase {
    func testMakefileKeepsStandardTestSuiteFreeOfMLXSkips() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fileURL = repoRoot.appendingPathComponent("Makefile")
        let source = try String(contentsOf: fileURL, encoding: .utf8)

        XCTAssertTrue(source.contains("$(SWIFT) test"))
        XCTAssertFalse(source.contains("--skip MLXSmokeTests"))
        XCTAssertTrue(source.contains("test-mlx:"))
    }

    func testDedicatedMLXSmokeScriptRunsPackagedAppBinary() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fileURL = repoRoot.appendingPathComponent("scripts/test-mlx.sh")
        let source = try String(contentsOf: fileURL, encoding: .utf8)

        XCTAssertTrue(source.contains("scripts/build-app.sh\" release --app-dir"))
        XCTAssertTrue(source.contains("Contents/MacOS/Fala\" mlx-smoke"))
        XCTAssertFalse(source.contains("xcodebuild"))
        XCTAssertFalse(source.contains("id="))
        XCTAssertFalse(source.contains("My Mac"))
    }

    func testMLXSmokeTestsStayUnitLevelAndNeverUseXCTSkip() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fileURL = repoRoot.appendingPathComponent("Tests/FalaTests/MLXSmokeTests.swift")
        let source = try String(contentsOf: fileURL, encoding: .utf8)

        XCTAssertFalse(source.contains("XCTSkip"))
        XCTAssertTrue(source.contains("MLXSmokeMode"))
    }
}
