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

    func testPackagingScriptsStageApplicationsShortcutInDMG() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let releaseSource = try String(
            contentsOf: repoRoot.appendingPathComponent("scripts/release.sh"),
            encoding: .utf8
        )
        let localSource = try String(
            contentsOf: repoRoot.appendingPathComponent("scripts/build-notarized-local.sh"),
            encoding: .utf8
        )

        XCTAssertTrue(releaseSource.contains("ln -s /Applications \"$DMG_STAGE_DIR/Applications\""))
        XCTAssertTrue(localSource.contains("ln -s /Applications \"$DMG_STAGE_DIR/Applications\""))
    }

    func testPackagingScriptsUseSharedDMGBuilder() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let releaseSource = try String(
            contentsOf: repoRoot.appendingPathComponent("scripts/release.sh"),
            encoding: .utf8
        )
        let localSource = try String(
            contentsOf: repoRoot.appendingPathComponent("scripts/build-notarized-local.sh"),
            encoding: .utf8
        )

        XCTAssertTrue(releaseSource.contains("scripts/create-dmg.sh"))
        XCTAssertTrue(localSource.contains("scripts/create-dmg.sh"))
        XCTAssertFalse(releaseSource.contains("hdiutil create -volname \"$APP_NAME\" -srcfolder"))
        XCTAssertFalse(localSource.contains("hdiutil create -volname \"$APP_NAME\" -srcfolder"))
    }

    func testSharedDMGBuilderUsesMountedImageFlow() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repoRoot.appendingPathComponent("scripts/create-dmg.sh"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("hdiutil attach"))
        XCTAssertTrue(source.contains("hdiutil convert"))
        XCTAssertTrue(source.contains("ditto \"$entry\" \"$destination\""))
        XCTAssertTrue(source.contains("ln -s \"$(readlink \"$entry\")\" \"$destination\""))
        XCTAssertTrue(source.contains("Assets/dmg-background.png"))
        XCTAssertTrue(source.contains("Sources/Fala/Resources/AppIcon.icns"))
        XCTAssertTrue(source.contains("/usr/bin/osascript \"$STYLE_SCRIPT\""))
        XCTAssertTrue(source.contains("SetFile -a C \"$MOUNT_POINT\""))
    }

    func testPremiumDMGAssetsAndStylingScriptExist() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let backgroundURL = repoRoot.appendingPathComponent("Assets/dmg-background.png")
        let scriptURL = repoRoot.appendingPathComponent("scripts/style-dmg.applescript")

        XCTAssertTrue(FileManager.default.fileExists(atPath: backgroundURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: scriptURL.path))

        let scriptSource = try String(contentsOf: scriptURL, encoding: .utf8)
        XCTAssertTrue(
            scriptSource.contains("set background picture of opts to file \".background:installer-background.png\"")
        )
        XCTAssertTrue(scriptSource.contains("set position of item \"Applications\""))
        XCTAssertTrue(scriptSource.contains("set position of item appName"))
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
