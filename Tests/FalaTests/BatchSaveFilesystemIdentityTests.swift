import XCTest
@testable import FalaCore

@MainActor
final class BatchSaveFilesystemIdentityTests: TranscriptionJobTestCase {
    func testRetryDoesNotOverwriteCompletedFileThroughCaseAlias() async throws {
        try await checkRetryCollision(throughSymlink: false)
    }

    func testRetryDoesNotOverwriteCompletedFileThroughSymlinkedDirectory() async throws {
        try await checkRetryCollision(throughSymlink: true)
    }

    private func checkRetryCollision(throughSymlink: Bool) async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let firstDirectory = directory.appendingPathComponent("first", isDirectory: true)
        let secondDirectory = directory.appendingPathComponent("second", isDirectory: true)
        for url in [firstDirectory, secondDirectory] {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        }
        let firstStem = throughSymlink ? "meeting" : "Meeting"
        let firstInput = try makeSilentWAV(in: firstDirectory, named: firstStem)
        let secondInput = try makeSilentWAV(in: secondDirectory, named: "meeting")
        let firstOutput = firstDirectory.appendingPathComponent(firstStem + ".txt")
        let engine = SaveFailureTranscriber(
            blockedOutput: secondDirectory.appendingPathComponent("meeting.txt"), blockedInput: secondInput
        )
        let job = makeSaveRecoveryJob(engine: engine)
        job.outputDirectory = nil
        job.enqueueInputFiles([firstInput, secondInput])
        job.transcribe()
        try await waitUntil { job.queue.allSatisfy(\.status.isTerminal) }
        XCTAssertEqual(job.completedQueueCount, 1)
        XCTAssertEqual(job.failedQueueCount, 1)

        var retryDirectory = firstDirectory
        if throughSymlink {
            retryDirectory = directory.appendingPathComponent("alias", isDirectory: true)
            try FileManager.default.createSymbolicLink(at: retryDirectory, withDestinationURL: firstDirectory)
        } else if !FileManager.default.fileExists(atPath: firstDirectory.appendingPathComponent("meeting.txt").path) {
            throw XCTSkip("This case-alias fixture requires a case-insensitive filesystem")
        }
        job.outputDirectory = retryDirectory
        job.transcribe()
        try await waitUntil { job.queue.allSatisfy(\.status.isTerminal) }

        let recoveredOutput = retryDirectory.appendingPathComponent("meeting-2.txt")
        XCTAssertEqual(try String(contentsOf: firstOutput, encoding: .utf8), "Primeira transcrição.\n")
        XCTAssertEqual(job.queue[1].status, .done(recoveredOutput, warning: nil))
        XCTAssertEqual(try String(contentsOf: recoveredOutput, encoding: .utf8), "Eu comunico com Niko.\n")
        let calls = await engine.calls
        XCTAssertEqual(calls, 2)
    }
}
