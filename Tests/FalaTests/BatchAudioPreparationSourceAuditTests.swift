import Foundation
import XCTest

final class BatchAudioPreparationSourceAuditTests: XCTestCase {
    func testRuntimeNoLongerDependsOnHomebrewFFmpeg() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let files = [
            "Sources/FalaCore/Modes/BatchMode.swift",
            "Sources/FalaCore/UI/TranscriptionJob+Processing.swift",
            "Sources/FalaCore/Core/Errors.swift"
        ].map { repoRoot.appendingPathComponent($0) }

        let source = try files
            .map { try String(contentsOf: $0, encoding: .utf8) }
            .joined(separator: "\n")

        XCTAssertFalse(source.contains("/opt/homebrew/bin/ffmpeg"))
        XCTAssertFalse(source.contains("brew install ffmpeg"))
        XCTAssertFalse(source.contains("FFmpegConverter"))
        XCTAssertTrue(source.contains("BatchAudioPreparer.prepareTranscriptionInput"))
    }
}
