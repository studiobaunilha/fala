import XCTest
@testable import FalaCore

@MainActor
final class BatchSaveRecoveryTests: TranscriptionJobTestCase {
    func testAppendFailureDoesNotCompleteQueueItem() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let inputURL = try makeSilentWAV(in: directory, named: "meeting")
        let outputURL = directory.appendingPathComponent("meeting.txt")
        let engine = SaveFailureTranscriber(blockedOutput: outputURL)
        let job = makeSaveRecoveryJob(engine: engine)
        job.outputDirectory = directory
        job.enqueueInputFiles([inputURL])

        job.transcribe()
        try await waitUntil { job.queue.allSatisfy(\.status.isTerminal) }

        let calls = await engine.calls
        XCTAssertEqual(calls, 1)
        XCTAssertThrowsError(try FileHandle(forWritingTo: outputURL))
        XCTAssertEqual(job.completedQueueCount, 0)
        XCTAssertEqual(job.failedQueueCount, 1)
        XCTAssertNil(job.queue.first?.status.outputURL)
        guard case .error = job.state else {
            return XCTFail("A failed transcript write must not report completion")
        }
    }

    func testCompletedTextCanBeSavedAgainWithoutRepeatingRecognition() async throws {
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
        let retainedText = try XCTUnwrap(job.queue.first?.recoverableText)
        XCTAssertEqual(retainedText, "Eu comunico com Niko.\n")

        try FileManager.default.removeItem(at: inputURL)
        job.outputDirectory = destination
        job.transcribe()
        try await waitUntil { job.queue.allSatisfy(\.status.isTerminal) }

        let outputURL = destination.appendingPathComponent("meeting.txt")
        XCTAssertEqual(job.queue.first?.status, .done(outputURL, warning: nil))
        XCTAssertEqual(try String(contentsOf: outputURL, encoding: .utf8), "Eu comunico com Niko.\n")
        XCTAssertNil(job.queue.first?.recoverableText)
        let calls = await engine.calls
        XCTAssertEqual(calls, 1)
    }

    func testRetrySaveDoesNotOverwriteAnotherCompletedItemWithSameName() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let firstDirectory = directory.appendingPathComponent("first", isDirectory: true)
        let secondDirectory = directory.appendingPathComponent("second", isDirectory: true)
        let destination = directory.appendingPathComponent("exports", isDirectory: true)
        for url in [firstDirectory, secondDirectory, destination] {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        }
        let firstInput = try makeSilentWAV(in: firstDirectory, named: "meeting")
        let secondInput = try makeSilentWAV(in: secondDirectory, named: "meeting")
        let firstOutput = destination.appendingPathComponent("meeting.txt")
        let secondOutput = destination.appendingPathComponent("meeting-2.txt")
        let engine = SaveFailureTranscriber(blockedOutput: secondOutput, blockedInput: secondInput)
        let job = makeSaveRecoveryJob(engine: engine)
        job.outputDirectory = destination
        job.enqueueInputFiles([firstInput, secondInput])
        job.transcribe()
        try await waitUntil { job.queue.allSatisfy(\.status.isTerminal) }
        XCTAssertEqual(job.completedQueueCount, 1)
        XCTAssertEqual(job.failedQueueCount, 1)

        try FileManager.default.removeItem(at: secondOutput)
        job.transcribe()
        try await waitUntil { job.queue.allSatisfy(\.status.isTerminal) }

        XCTAssertEqual(job.queue.map(\.status), [.done(firstOutput, warning: nil), .done(secondOutput, warning: nil)])
        XCTAssertEqual(try String(contentsOf: firstOutput, encoding: .utf8), "Primeira transcrição.\n")
        XCTAssertEqual(try String(contentsOf: secondOutput, encoding: .utf8), "Eu comunico com Niko.\n")
        let calls = await engine.calls
        XCTAssertEqual(calls, 2)
    }

    func testRetainedSaveRetryDoesNotRequireSpeechModelReadinessOrWarmup() async throws {
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
        let initialLoads = await engine.loads

        job.appSettings.transcriptionEngine = "whisper"
        job.appSettings.activeWhisperModel = "none"
        XCTAssertNotNil(job.appSettings.readiness.primaryIssueForBatch(batchPrompt: ""))
        XCTAssertNil(job.readinessIssueForNextRun)
        job.outputDirectory = destination
        job.transcribe()
        try await waitUntil { job.queue.allSatisfy(\.status.isTerminal) }

        XCTAssertEqual(job.completedQueueCount, 1)
        let loads = await engine.loads
        let calls = await engine.calls
        XCTAssertEqual(loads, initialLoads)
        XCTAssertEqual(calls, 1)
    }

    func testFreshQueueItemStillRequiresSpeechModelReadiness() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let inputURL = try makeSilentWAV(in: directory, named: "meeting")
        let engine = SaveFailureTranscriber(blockedOutput: directory.appendingPathComponent("meeting.txt"))
        let job = makeSaveRecoveryJob(engine: engine)
        job.outputDirectory = directory
        job.appSettings.transcriptionEngine = "whisper"
        job.appSettings.activeWhisperModel = "none"
        job.enqueueInputFiles([inputURL])

        XCTAssertEqual(job.readinessIssueForNextRun?.kind, .whisperModelMissing)
        job.transcribe()
        try await waitUntil {
            if case .error = job.state { return true }
            return false
        }

        XCTAssertEqual(job.queue.first?.status, .pending)
        let calls = await engine.calls
        XCTAssertEqual(calls, 0)
    }

}

actor SaveFailureTranscriber {
    let blockedOutput: URL
    let blockedInput: URL?
    let pauseAfterPartial: Bool
    private(set) var calls = 0
    private(set) var loads = 0

    func recordLoad() {
        loads += 1
    }

    init(blockedOutput: URL, blockedInput: URL? = nil, pauseAfterPartial: Bool = false) {
        self.blockedOutput = blockedOutput
        self.blockedInput = blockedInput
        self.pauseAfterPartial = pauseAfterPartial
    }

    func transcribe(
        path: String,
        progress: (@Sendable (TranscriberProgress) -> Void)?
    ) async throws -> String {
        calls += 1
        let input = URL(fileURLWithPath: path)
        let shouldBlock = input.deletingPathExtension().lastPathComponent == "meeting"
            && (blockedInput == nil || input == blockedInput)
        if shouldBlock {
            try FileManager.default.removeItem(at: blockedOutput)
            try FileManager.default.createDirectory(at: blockedOutput, withIntermediateDirectories: false)
        }
        if pauseAfterPartial {
            progress?(TranscriberProgress(text: "Primeira parte", windowId: 0))
            progress?(TranscriberProgress(text: "Ainda em andamento", windowId: 1))
            try await Task.sleep(for: .seconds(5))
        }
        let text = blockedInput != nil && !shouldBlock ? "Primeira transcrição." : "Eu comunico com Niko."
        progress?(TranscriberProgress(text: text, windowId: 0))
        return text
    }
}

@MainActor
func makeSaveRecoveryJob(engine: SaveFailureTranscriber, config: AppConfig = AppConfig()) -> TranscriptionJob {
    let pool = BatchTranscriberPool(
        whisperFactory: {
            BatchWhisperTranscriber(
                loadState: { .ready }, loadIfNeeded: { _ in await engine.recordLoad() },
                setModel: { _ in }, setConfig: { _, _, _ in },
                transcribeSamples: { _, _ in "" },
                transcribeAudioPath: { path, _, progress in
                    try await engine.transcribe(path: path, progress: progress)
                }
            )
        },
        parakeetFactory: {
            BatchPreloadableTranscriber(
                loadState: { .ready }, loadIfNeeded: { _ in await engine.recordLoad() },
                transcribeSamples: { _, _ in "" },
                transcribeAudioPath: { path, _, progress in
                    try await engine.transcribe(path: path, progress: progress)
                }
            )
        }
    )
    let job = TranscriptionJob(appSettings: makeTestSettings(config: config), batchTranscriberPool: pool)
    job.outputFormat = "txt"
    return job
}
