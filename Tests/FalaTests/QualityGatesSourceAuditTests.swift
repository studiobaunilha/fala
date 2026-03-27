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

    func testSwiftTestRunsWithWarningsAsErrors() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fileURL = repoRoot.appendingPathComponent("scripts/swift-env.sh")
        let source = try String(contentsOf: fileURL, encoding: .utf8)

        XCTAssertTrue(source.contains("-Xswiftc -warnings-as-errors"))
    }

    func testLocalTargetsTreatWarningsAsErrorsForBuilds() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let packageURL = repoRoot.appendingPathComponent("Package.swift")
        let packageSource = try String(contentsOf: packageURL, encoding: .utf8)

        XCTAssertTrue(packageSource.contains("let localWarningsAsErrorsSwiftSettings"))
        XCTAssertTrue(packageSource.contains(".unsafeFlags([\"-warnings-as-errors\"])"))
        XCTAssertTrue(packageSource.contains("swiftSettings: localWarningsAsErrorsSwiftSettings"))
        XCTAssertTrue(packageSource.contains("swiftSettings: macOSXCTestSettings + localWarningsAsErrorsSwiftSettings"))
    }

    func testXcodeBuildDoesNotForceSwiftWarningsAsErrorsOnSourcePackages() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fileURL = repoRoot.appendingPathComponent("scripts/build-app.sh")
        let source = try String(contentsOf: fileURL, encoding: .utf8)

        XCTAssertFalse(source.contains("SWIFT_TREAT_WARNINGS_AS_ERRORS=YES"))
        XCTAssertTrue(source.contains("GCC_TREAT_WARNINGS_AS_ERRORS=YES"))
        XCTAssertTrue(source.contains("CLANG_TREAT_WARNINGS_AS_ERRORS=YES"))
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
