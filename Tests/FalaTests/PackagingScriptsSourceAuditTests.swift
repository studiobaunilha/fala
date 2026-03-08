import Foundation
import XCTest

final class PackagingScriptsSourceAuditTests: XCTestCase {
    func testReleaseScriptUsesSharedAppBundleBuilder() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fileURL = repoRoot.appendingPathComponent("scripts/release.sh")
        let source = try String(contentsOf: fileURL, encoding: .utf8)

        XCTAssertTrue(source.contains("scripts/build-app.sh\" release --app-dir"))
        XCTAssertFalse(source.contains("swift build -c release"))
        XCTAssertFalse(source.contains("cp -R .build/release/Sparkle.framework"))
    }

    func testBuildScriptVerifiesStagedRuntimeContents() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fileURL = repoRoot.appendingPathComponent("scripts/build-app.sh")
        let source = try String(contentsOf: fileURL, encoding: .utf8)

        XCTAssertTrue(source.contains("verify_staged_bundle_contents"))
        XCTAssertTrue(source.contains("mlx-swift_Cmlx.bundle/Contents/Resources/default.metallib"))
        XCTAssertTrue(source.contains("find \"$PRODUCTS_DIR\" -maxdepth 1 -type d -name '*.bundle'"))
        XCTAssertTrue(source.contains("find \"$PRODUCTS_DIR\" -maxdepth 1 -type d -name '*.framework'"))
    }
}
