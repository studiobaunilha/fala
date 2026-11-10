import Foundation
import XCTest

final class AppBundleMetadataTests: XCTestCase {
    func testDistributionMetadataResolvesAnApplicationExecutable() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let app = directory.appendingPathComponent("Fala.app", isDirectory: true)
        let contents = app.appendingPathComponent("Contents", isDirectory: true)
        let executable = contents.appendingPathComponent("MacOS/Fala")
        try FileManager.default.createDirectory(
            at: executable.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.copyItem(
            at: repoRoot.appendingPathComponent("Sources/Fala/Resources/Info.plist"),
            to: contents.appendingPathComponent("Info.plist")
        )
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

        let bundle = try XCTUnwrap(Bundle(url: app))
        XCTAssertEqual(bundle.infoDictionary?["CFBundlePackageType"] as? String, "APPL")
        XCTAssertEqual(bundle.executableURL?.standardizedFileURL, executable.standardizedFileURL)
    }
}
