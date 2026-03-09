import XCTest
@testable import FalaCore

@MainActor
final class TranscriptionJobPipelineTests: TranscriptionJobTestCase {
    func testTranscribeReportsPreparingModelBeforeAudioTranscriptionStarts() async throws {
        var config = AppConfig()
        config.transcriptionEngine = "parakeet"
        let transcriberSpy = DelayedBatchTranscriberSpy(
            loadDelay: .milliseconds(200),
            transcribeDelay: .milliseconds(10)
        )
        let job = TranscriptionJob(
            appSettings: makeTestSettings(config: config),
            batchTranscriberPool: makeDelayedBatchPool(spy: transcriberSpy)
        )
        let inputDir = try makeTemporaryDirectory()
        let outputDir = try makeTemporaryDirectory()
        let inputURL = try makeSilentWAV(in: inputDir, named: "preparo-modelo")
        job.outputDirectory = outputDir

        job.enqueueInputFiles([inputURL])
        job.transcribe()
        try await transcriberSpy.waitForLoadStart()
        try await waitUntil {
            job.state == .preparingModel
        }

        XCTAssertEqual(job.queue.map(\.status), [.preparingModel])

        try await waitUntil {
            job.queue.allSatisfy(\.status.isTerminal)
        }
        let transcribeCallCount = await transcriberSpy.transcribeAudioCallCount()
        XCTAssertEqual(transcribeCallCount, 1)
    }

    func testCancelDuringModelPreparationStopsBeforeTranscriptionBegins() async throws {
        var config = AppConfig()
        config.transcriptionEngine = "parakeet"
        let transcriberSpy = DelayedBatchTranscriberSpy(loadDelay: .seconds(5))
        let job = TranscriptionJob(
            appSettings: makeTestSettings(config: config),
            batchTranscriberPool: makeDelayedBatchPool(spy: transcriberSpy)
        )
        let inputDir = try makeTemporaryDirectory()
        let outputDir = try makeTemporaryDirectory()
        let firstURL = try makeSilentWAV(in: inputDir, named: "primeiro")
        let secondURL = try makeSilentWAV(in: inputDir, named: "segundo")
        job.outputDirectory = outputDir

        job.enqueueInputFiles([firstURL, secondURL])
        job.transcribe()
        try await transcriberSpy.waitForLoadStart()

        job.cancel()
        XCTAssertTrue(job.isCancelling)

        try await waitUntil {
            job.queue.allSatisfy(\.status.isTerminal)
        }

        XCTAssertEqual(job.state, .error(L10n("Cancelado pelo usuário")))
        XCTAssertEqual(job.queue.map(\.status), [.cancelled, .cancelled])
        let transcribeCallCount = await transcriberSpy.transcribeAudioCallCount()
        XCTAssertEqual(transcribeCallCount, 0)
        XCTAssertFalse(job.isCancelling)
    }

    func testCancelDuringAudioPreparationStopsBeforeModelPreparationBegins() async throws {
        var config = AppConfig()
        config.transcriptionEngine = "parakeet"
        let transcriberSpy = DelayedBatchTranscriberSpy(loadDelay: .zero)
        let audioPreparationSpy = DelayedBatchAudioPreparationSpy(delay: .seconds(5))
        let job = TranscriptionJob(
            appSettings: makeTestSettings(config: config),
            batchTranscriberPool: makeDelayedBatchPool(spy: transcriberSpy),
            audioPreparationHandler: { inputURL in
                try await audioPreparationSpy.prepare(inputURL: inputURL)
            }
        )
        let inputDir = try makeTemporaryDirectory()
        let outputDir = try makeTemporaryDirectory()
        let inputURL = inputDir.appendingPathComponent("convertendo").appendingPathExtension("m4a")
        FileManager.default.createFile(atPath: inputURL.path, contents: Data())
        job.outputDirectory = outputDir

        job.enqueueInputFiles([inputURL])
        job.transcribe()
        try await audioPreparationSpy.waitForStart()
        try await waitUntil {
            job.state == .converting
        }

        job.cancel()
        XCTAssertTrue(job.isCancelling)

        try await waitUntil {
            job.queue.allSatisfy(\.status.isTerminal)
        }

        XCTAssertEqual(job.state, .error(L10n("Cancelado pelo usuário")))
        XCTAssertEqual(job.queue.map(\.status), [.cancelled])
        let transcribeCallCount = await transcriberSpy.transcribeAudioCallCount()
        XCTAssertEqual(transcribeCallCount, 0)
        XCTAssertNil(job.lastExecutionMetrics?.modelPreparation)
        XCTAssertFalse(job.isCancelling)
    }

    func testTranscribeCapturesStageMetricsForSuccessfulRun() async throws {
        var config = AppConfig()
        config.transcriptionEngine = "parakeet"
        let transcriberSpy = DelayedBatchTranscriberSpy(
            loadDelay: .milliseconds(20),
            transcribeDelay: .milliseconds(20)
        )
        let job = TranscriptionJob(
            appSettings: makeTestSettings(config: config),
            batchTranscriberPool: makeDelayedBatchPool(spy: transcriberSpy)
        )
        let inputDir = try makeTemporaryDirectory()
        let outputDir = try makeTemporaryDirectory()
        let inputURL = try makeSilentWAV(in: inputDir, named: "metricas")
        job.outputDirectory = outputDir

        job.enqueueInputFiles([inputURL])
        job.transcribe()

        try await waitUntil {
            job.queue.allSatisfy(\.status.isTerminal)
        }

        let metrics = try XCTUnwrap(job.lastExecutionMetrics)
        XCTAssertEqual(metrics.fileName, "metricas.wav")
        XCTAssertEqual(metrics.fileExtension, "wav")
        XCTAssertEqual(metrics.outcome, .succeeded)
        XCTAssertNil(metrics.postProcessing)
        XCTAssertGreaterThan(metrics.total, .zero)
        XCTAssertGreaterThan(try XCTUnwrap(metrics.audioPreparation), .zero)
        XCTAssertGreaterThan(try XCTUnwrap(metrics.modelPreparation), .zero)
        XCTAssertGreaterThan(try XCTUnwrap(metrics.transcription), .zero)
    }
}
