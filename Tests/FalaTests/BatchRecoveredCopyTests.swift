import AppKit
import XCTest
@testable import FalaCore

@MainActor
final class BatchRecoveredCopyTests: TranscriptionJobTestCase {
    func testCopyAfterSaveFailureWritesExactCompleteTextToIsolatedPasteboard() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let input = try makeSilentWAV(in: directory, named: "meeting")
        let engine = SaveFailureTranscriber(blockedOutput: directory.appendingPathComponent("meeting.txt"))
        let job = makeSaveRecoveryJob(engine: engine)
        job.outputDirectory = directory
        job.enqueueInputFiles([input])
        job.transcribe()
        try await waitUntil { job.queue.allSatisfy(\.status.isTerminal) }
        let item = try XCTUnwrap(job.queue.first)
        XCTAssertEqual(job.failedQueueCount, 1)
        XCTAssertEqual(item.recoverableText, "Eu comunico com Niko.\n")
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        XCTAssertTrue(pasteboard.setString("private sentinel", forType: .string))

        job.copyRecoveredTranscript(for: item.id, to: pasteboard)

        XCTAssertEqual(pasteboard.string(forType: .string), "Eu comunico com Niko.\n")
        XCTAssertEqual(job.queue.first?.recoverableText, item.recoverableText)
        let calls = await engine.calls
        XCTAssertEqual(calls, 1)
        print("[BatchCopy] named board sink=\(String(reflecting: pasteboard.string(forType: .string)))")
    }

    func testMissingRecoverableResultDoesNotClearIsolatedPasteboard() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let input = try makeSilentWAV(in: directory, named: "pending-copy-fixture")
        let engine = SaveFailureTranscriber(blockedOutput: directory.appendingPathComponent("unused.txt"))
        let job = makeSaveRecoveryJob(engine: engine)
        job.enqueueInputFiles([input])
        let item = try XCTUnwrap(job.queue.first)
        XCTAssertNil(item.recoverableText)
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        XCTAssertTrue(pasteboard.setString("private sentinel", forType: .string))

        job.copyRecoveredTranscript(for: item.id, to: pasteboard)

        XCTAssertEqual(pasteboard.string(forType: .string), "private sentinel")
    }
}
