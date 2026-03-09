import Foundation
import XCTest

final class CLISourceAuditTests: XCTestCase {
    func testCLIEntryPointNoLongerBlocksAsyncWorkWithSemaphore() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let mainSource = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/Fala/FalaMain.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(mainSource.contains("@main"))
        XCTAssertFalse(mainSource.contains("DispatchSemaphore"))
        XCTAssertFalse(mainSource.contains("semaphore.wait"))
        XCTAssertTrue(mainSource.contains("try await BatchMode.run"))
        XCTAssertTrue(mainSource.contains("--prepare-only"))
    }
}
