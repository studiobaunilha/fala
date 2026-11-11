import Foundation
import XCTest

final class BatchCLIIntegrationTests: XCTestCase {
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func builtCLIURL() throws -> URL {
        let buildRoot = repoRoot.appendingPathComponent(".build")
        var candidates = try FileManager.default.contentsOfDirectory(
            at: buildRoot,
            includingPropertiesForKeys: nil
        )
            .filter { $0.lastPathComponent.contains("apple-macosx") }
            .map { $0.appendingPathComponent("debug").appendingPathComponent("Fala") }

        candidates.append(buildRoot.appendingPathComponent("out/Products/Debug/Fala"))

        guard let executable = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0.path) }) else {
            XCTFail("Built CLI executable not found under .build")
            throw NSError(domain: "BatchCLIIntegrationTests", code: 1)
        }

        return executable
    }

    func testPrepareOnlyCLIHandlesExportedAACInput() async throws {
        let executableURL = try builtCLIURL()
        let inputURL = try await makeExportedAACM4A(
            sampleRate: 48_000,
            durationSeconds: 0.5
        )
        defer { try? FileManager.default.removeItem(at: inputURL) }

        let process = Process()
        process.executableURL = executableURL
        process.currentDirectoryURL = repoRoot
        process.arguments = [
            "transcribe",
            inputURL.path,
            "--prepare-only",
            "--profile"
        ]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let stdoutText = String(
            data: stdout.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""
        let stderrText = String(
            data: stderr.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""

        XCTAssertEqual(process.terminationStatus, 0, stderrText)
        XCTAssertTrue(stdoutText.contains("Audio prepared."), stdoutText)
        XCTAssertTrue(stderrText.contains("audioMode=converted"), stderrText)
        XCTAssertTrue(stderrText.contains("model=n/a"), stderrText)
        XCTAssertTrue(stderrText.contains("transcribe=n/a"), stderrText)
        XCTAssertTrue(stderrText.contains("outcome=succeeded"), stderrText)
    }
}
