import XCTest
@testable import FalaCore

@MainActor
final class BatchSaveRecoveryControlTests: TranscriptionJobTestCase {
    func testFailedRetryRetainsTextAndOtherCompletedFiles() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let failedInput = try makeSilentWAV(in: directory, named: "meeting")
        let successfulInput = try makeSilentWAV(in: directory, named: "notes")
        let engine = SaveFailureTranscriber(blockedOutput: directory.appendingPathComponent("meeting.txt"))
        let job = makeSaveRecoveryJob(engine: engine)
        job.outputDirectory = directory
        job.enqueueInputFiles([failedInput, successfulInput])
        job.transcribe()
        try await waitUntil { job.queue.allSatisfy(\.status.isTerminal) }
        let savedURL = directory.appendingPathComponent("notes.txt")
        XCTAssertEqual(job.completedQueueCount, 1)
        XCTAssertEqual(job.failedQueueCount, 1)

        job.transcribe()
        try await waitUntil { job.queue.allSatisfy(\.status.isTerminal) }

        XCTAssertEqual(job.failedQueueCount, 1)
        XCTAssertEqual(job.queue[0].recoverableText, "Eu comunico com Niko.\n")
        XCTAssertNil(job.queue[0].status.outputURL)
        XCTAssertEqual(job.queue[1].status, .done(savedURL, warning: nil))
        XCTAssertEqual(try String(contentsOf: savedURL, encoding: .utf8), "Eu comunico com Niko.\n")
        let calls = await engine.calls
        XCTAssertEqual(calls, 2)
    }

    func testInitializationFailureHasNoCompleteResultOrRecognition() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let inputURL = try makeSilentWAV(in: directory, named: "meeting")
        let blockedOutput = directory.appendingPathComponent("meeting.txt")
        try FileManager.default.createDirectory(at: blockedOutput, withIntermediateDirectories: false)
        let engine = SaveFailureTranscriber(blockedOutput: blockedOutput)
        let job = makeSaveRecoveryJob(engine: engine)
        job.outputDirectory = directory
        job.enqueueInputFiles([inputURL])

        job.transcribe()
        try await waitUntil { job.queue.allSatisfy(\.status.isTerminal) }

        XCTAssertEqual(job.failedQueueCount, 1)
        XCTAssertEqual(job.completedQueueCount, 0)
        XCTAssertNil(job.queue.first?.recoverableText)
        let calls = await engine.calls
        XCTAssertEqual(calls, 0)
    }

    func testRetryCanSerializeRetainedTextAsMarkdownWithoutReapplyingCorrections() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("recovered", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
        let inputURL = try makeSilentWAV(in: directory, named: "meeting")
        let engine = SaveFailureTranscriber(blockedOutput: directory.appendingPathComponent("meeting.txt"))
        let job = makeSaveRecoveryJob(engine: engine)
        job.outputDirectory = directory
        job.enqueueInputFiles([inputURL])
        job.transcribe()
        try await waitUntil { job.queue.allSatisfy(\.status.isTerminal) }

        job.appSettings.replacementRules = [ReplacementRule(variants: ["Niko"], replacement: "Nicolau")]
        job.outputFormat = "md"
        job.outputDirectory = destination
        job.transcribe()
        try await waitUntil { job.queue.allSatisfy(\.status.isTerminal) }

        let outputURL = destination.appendingPathComponent("meeting.md")
        XCTAssertEqual(try String(contentsOf: outputURL, encoding: .utf8), "# meeting\n\nEu comunico com Niko.\n")
        XCTAssertEqual(job.queue.first?.status, .done(outputURL, warning: nil))
        let calls = await engine.calls
        XCTAssertEqual(calls, 1)
    }

    func testCancellationAfterFailedPartialAppendDoesNotCreateCompleteRecovery() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let inputURL = try makeSilentWAV(in: directory, named: "meeting")
        let engine = SaveFailureTranscriber(
            blockedOutput: directory.appendingPathComponent("meeting.txt"),
            pauseAfterPartial: true
        )
        let job = makeSaveRecoveryJob(engine: engine)
        job.outputDirectory = directory
        job.enqueueInputFiles([inputURL])
        job.transcribe()
        try await waitUntil { job.queue.first?.status == .transcribing("Ainda em andamento") }

        job.cancel()
        try await waitUntil { job.queue.allSatisfy(\.status.isTerminal) }

        XCTAssertEqual(job.queue.first?.status, .cancelled)
        XCTAssertNil(job.queue.first?.recoverableText)
        XCTAssertEqual(job.completedQueueCount, 0)
    }

    func testSaveRetryDoesNotRepeatSuccessfulLLMPostProcessing() async throws {
        URLProtocol.registerClass(SaveRecoveryLLMProtocol.self)
        SaveRecoveryLLMProtocol.counter.reset()
        defer { URLProtocol.unregisterClass(SaveRecoveryLLMProtocol.self) }
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("recovered", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
        let inputURL = try makeSilentWAV(in: directory, named: "meeting")
        let engine = SaveFailureTranscriber(blockedOutput: directory.appendingPathComponent("meeting.txt"))
        var config = AppConfig()
        config.llmProvider = "openai"
        config.openAIKey = "fala-save-recovery-no-network"
        let job = makeSaveRecoveryJob(engine: engine, config: config)
        job.batchPostPrompt = "Corrija a pontuação."
        job.outputDirectory = directory
        job.enqueueInputFiles([inputURL])
        job.transcribe()
        try await waitUntil { job.queue.allSatisfy(\.status.isTerminal) }
        XCTAssertEqual(SaveRecoveryLLMProtocol.counter.count, 1)
        XCTAssertEqual(job.queue.first?.recoverableText, "Texto aprimorado.\n")

        job.outputDirectory = destination
        job.transcribe()
        try await waitUntil { job.queue.allSatisfy(\.status.isTerminal) }

        XCTAssertEqual(SaveRecoveryLLMProtocol.counter.count, 1)
        XCTAssertEqual(job.completedQueueCount, 1)
        let outputURL = destination.appendingPathComponent("meeting.txt")
        XCTAssertEqual(try String(contentsOf: outputURL, encoding: .utf8), "Texto aprimorado.\n")
    }

}
