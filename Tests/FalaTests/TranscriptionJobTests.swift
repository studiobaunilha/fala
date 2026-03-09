import XCTest
@testable import FalaCore

@MainActor
final class TranscriptionJobTests: TranscriptionJobTestCase {
    func testInitialStateIsIdle() {
        let job = TranscriptionJob(appSettings: makeTestSettings())
        XCTAssertEqual(job.state, .idle)
        XCTAssertNil(job.inputURL)
    }

    func testResetClearsState() {
        let job = TranscriptionJob(appSettings: makeTestSettings())
        job.inputURL = URL(fileURLWithPath: "/tmp/test.wav")
        job.state = .error("Test error")

        job.reset()

        XCTAssertEqual(job.state, .idle)
        XCTAssertNil(job.inputURL)
    }

    func testTranscribeRequiresInputURL() {
        let job = TranscriptionJob(appSettings: makeTestSettings())
        job.transcribe() // No inputURL set

        XCTAssertEqual(job.state, .idle) // Remains idle
    }

    func testOutputFormatDefaultsFromConfig() {
        // Just verify it doesn't crash and gets a string (from default AppConfig)
        let job = TranscriptionJob(appSettings: makeTestSettings())
        XCTAssertFalse(job.outputFormat.isEmpty)
    }

    func testPrepareForUseWarmsPoolWithOverrideModelAndLanguage() async {
        let whisperSpy = TranscriptionJobWhisperBatchSpy()
        var config = AppConfig()
        config.transcriptionEngine = "whisper"
        let job = TranscriptionJob(
            appSettings: makeTestSettings(config: config),
            batchTranscriberPool: makeTestBatchPool(whisperSpy: whisperSpy)
        )
        job.overrideModel = "medium"
        job.overrideLanguage = "pt-BR"

        job.prepareForUse()
        try? await Task.sleep(for: .milliseconds(20))

        let snapshot = await whisperSpy.snapshot()
        XCTAssertEqual(snapshot.models, ["medium"])
        XCTAssertEqual(snapshot.languages, ["pt-BR"])
        XCTAssertEqual(snapshot.loadCount, 1)
    }

    func testResetClearsProcessingWarning() {
        let job = TranscriptionJob(appSettings: makeTestSettings())
        job.processingWarning = BatchProcessingWarning(
            title: "Aviso",
            message: "Detalhe"
        )

        job.reset()

        XCTAssertNil(job.processingWarning)
    }

    func testApplyLLMWithOutcomeReturnsWarningWhenMLXFails() async {
        var config = AppConfig()
        config.llmProvider = "mlx"
        config.mlxModel = "mlx-community/fala-test-missing-model"

        let outcome = await TranscriptionJob.applyLLMWithOutcome(
            to: "Texto original",
            config: config,
            template: .askAI
        )

        XCTAssertEqual(outcome.text, "Texto original")
        XCTAssertEqual(outcome.warning?.title, "Pós-processamento com IA não foi aplicado")
        XCTAssertTrue(
            outcome.warning?.message.contains("MLX Local") == true
        )
    }

    func testEnqueueInputFilesAddsSupportedFilesInOrderSkippingDuplicatesAndUnsupported() throws {
        let job = TranscriptionJob(appSettings: makeTestSettings())
        let tempDir = try makeTemporaryDirectory()
        let wavA = tempDir.appendingPathComponent("a.wav")
        let wavB = tempDir.appendingPathComponent("b.mp3")
        let unsupported = tempDir.appendingPathComponent("notes.txt")
        FileManager.default.createFile(atPath: wavA.path, contents: Data())
        FileManager.default.createFile(atPath: wavB.path, contents: Data())
        FileManager.default.createFile(atPath: unsupported.path, contents: Data())

        job.enqueueInputFiles([wavA, unsupported, wavB, wavA])

        XCTAssertEqual(job.queue.map(\.inputURL.lastPathComponent), ["a.wav", "b.mp3"])
        XCTAssertEqual(job.inputURL?.lastPathComponent, "a.wav")
        XCTAssertEqual(job.state, .idle)
    }

    func testTranscribeProcessesQueuedFilesSequentiallyAndWritesOutputs() async throws {
        let transcriberSpy = BatchQueueTranscriberSpy()
        let job = TranscriptionJob(
            appSettings: makeTestSettings(),
            batchTranscriberPool: makeTestBatchPool(queueSpy: transcriberSpy)
        )
        let inputDir = try makeTemporaryDirectory()
        let outputDir = try makeTemporaryDirectory()
        let firstURL = try makeSilentWAV(in: inputDir, named: "primeiro")
        let secondURL = try makeSilentWAV(in: inputDir, named: "segundo")
        job.outputDirectory = outputDir

        job.enqueueInputFiles([firstURL, secondURL])
        job.transcribe()

        try await waitUntil {
            job.queue.allSatisfy(\.status.isTerminal)
        }

        let snapshot = await transcriberSpy.snapshot()
        XCTAssertEqual(snapshot.audioPaths, [firstURL.path, secondURL.path])

        let firstOutput = outputDir.appendingPathComponent("primeiro.txt")
        let secondOutput = outputDir.appendingPathComponent("segundo.txt")

        XCTAssertEqual(try String(contentsOf: firstOutput, encoding: .utf8), "PRIMEIRO\n")
        XCTAssertEqual(try String(contentsOf: secondOutput, encoding: .utf8), "SEGUNDO\n")
        XCTAssertEqual(job.queue.map(\.status), [
            .done(firstOutput, warning: nil),
            .done(secondOutput, warning: nil)
        ])
    }

    func testTranscribeDisambiguatesOutputsForDuplicateBasenamesInCustomOutputDirectory() async throws {
        let transcriberSpy = BatchQueueTranscriberSpy()
        let job = TranscriptionJob(
            appSettings: makeTestSettings(),
            batchTranscriberPool: makeTestBatchPool(queueSpy: transcriberSpy)
        )
        let rootDir = try makeTemporaryDirectory()
        let inputDirA = rootDir.appendingPathComponent("a", isDirectory: true)
        let inputDirB = rootDir.appendingPathComponent("b", isDirectory: true)
        try FileManager.default.createDirectory(at: inputDirA, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: inputDirB, withIntermediateDirectories: true)
        let outputDir = rootDir.appendingPathComponent("saida", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        let firstURL = try makeSilentWAV(in: inputDirA, named: "reuniao")
        let secondURL = try makeSilentWAV(in: inputDirB, named: "reuniao")
        job.outputDirectory = outputDir

        job.enqueueInputFiles([firstURL, secondURL])
        job.transcribe()

        try await waitUntil {
            job.queue.allSatisfy(\.status.isTerminal)
        }

        let firstOutput = outputDir.appendingPathComponent("reuniao.txt")
        let secondOutput = outputDir.appendingPathComponent("reuniao-2.txt")

        XCTAssertTrue(FileManager.default.fileExists(atPath: firstOutput.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: secondOutput.path))
        XCTAssertEqual(try String(contentsOf: firstOutput, encoding: .utf8), "REUNIAO\n")
        XCTAssertEqual(try String(contentsOf: secondOutput, encoding: .utf8), "REUNIAO\n")
    }
}
