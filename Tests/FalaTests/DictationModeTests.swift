import XCTest
import AVFoundation
@testable import FalaCore

// MARK: – Tests

final class DictationModeTests: XCTestCase, @unchecked Sendable {

    // swiftlint:disable implicitly_unwrapped_optional
    // Standard XCTest pattern: always set in setUp before any test runs.
    private var recorder: MockRecorder!
    private var transcriber: MockTranscriber!
    private var inserter: MockInserter!
    private var mode: DictationMode!
    private var prewarmer: DictationPrewarmerSpy!
    // swiftlint:enable implicitly_unwrapped_optional

    override func setUp() {
        super.setUp()
        recorder    = MockRecorder()
        transcriber = MockTranscriber()
        inserter    = MockInserter()
        prewarmer   = DictationPrewarmerSpy()
        // DictationMode.init is @MainActor. XCTest runs setUp on the main
        // thread, so assumeIsolated is safe here.
        MainActor.assumeIsolated {

            // Inject a clean config so tests never depend on user state
            var testConfig = AppConfig()
            testConfig.selectedDictationTemplate = .raw
            mode = DictationMode(
                recorder: recorder,
                transcriber: transcriber,
                inserter: inserter,
                config: testConfig,
                transcriberPrewarmer: { config in
                    await self.prewarmer.record(config: config)
                }
            )
        }
    }

    // MARK: – startRecording
    // async test methods in XCTest run on the MainActor, so @MainActor calls are direct.

    func testStartRecordingCallsRecorder() async {
        await mode.startRecording()
        XCTAssertEqual(recorder.startCallCount, 1)
    }

    func testStartRecordingIsIdempotentWhenAlreadyRecording() async {
        await mode.startRecording()
        await mode.startRecording() // second call should be ignored
        XCTAssertEqual(recorder.startCallCount, 1, "Should not start a second recording")
    }

    // MARK: – stopAndTranscribe

    func testStopAndTranscribeCallsStopOnRecorder() async throws {
        let url = try makeSilentWAV()
        recorder.stopResult = .success(url)
        defer { try? FileManager.default.removeItem(at: url) }

        await mode.startRecording()
        await mode.stopAndTranscribe()

        XCTAssertEqual(recorder.stopCallCount, 1)
    }

    func testStopAndTranscribeInsertsTranscribedText() async throws {
        let url = try makeWAVWithTone(seconds: 0.1)
        recorder.stopResult = .success(url)
        defer { try? FileManager.default.removeItem(at: url) }

        await transcriber.setResult("Bonjour le monde")
        await mode.startRecording()
        await mode.stopAndTranscribe()

        XCTAssertFalse(inserter.insertedTexts.isEmpty)
        XCTAssertEqual(inserter.insertedTexts.first, "Bonjour le monde")
    }

    func testStopAndTranscribeDoesNotInsertEmptyText() async throws {
        let url = try makeWAVWithTone(seconds: 0.1)
        recorder.stopResult = .success(url)
        defer { try? FileManager.default.removeItem(at: url) }

        await transcriber.setResult("")
        await mode.startRecording()
        await mode.stopAndTranscribe()

        XCTAssertTrue(inserter.insertedTexts.isEmpty)
    }

    func testStopAndTranscribeSkipsSilentAudio() async throws {
        let url = try makeSilentWAV(seconds: 0.1)
        recorder.stopResult = .success(url)
        defer { try? FileManager.default.removeItem(at: url) }

        await transcriber.setResult("Hello world")
        await mode.startRecording()
        await mode.stopAndTranscribe()

        XCTAssertTrue(inserter.insertedTexts.isEmpty, "Silent audio should not produce any output")
        let callCount = await transcriber.sampleCallCount
        XCTAssertEqual(callCount, 0, "Transcriber should not be called for silent audio")
    }

    func testStopAndTranscribeSkipsShortNoiseHallucination() async throws {
        let url = try makeWAVWithTone(seconds: 0.1)
        recorder.stopResult = .success(url)
        defer { try? FileManager.default.removeItem(at: url) }

        await transcriber.setResult("the")
        await mode.startRecording()
        await mode.stopAndTranscribe()

        XCTAssertTrue(inserter.insertedTexts.isEmpty, "Short noise artifacts should be filtered")
    }

    func testStopAndTranscribeHandlesRecorderError() async {
        recorder.stopResult = .failure(AudioError.noRecording)

        await mode.startRecording()
        await mode.stopAndTranscribe() // must not crash

        XCTAssertTrue(inserter.insertedTexts.isEmpty)
    }

    func testStopAndTranscribeUsesResolvedTranscriberFromCurrentConfig() async throws {
        let whisper = MockTranscriber(supportsTranslation: true)
        let parakeet = MockTranscriber(supportsTranslation: false)
        let url = try makeWAVWithTone(seconds: 0.1)
        recorder.stopResult = .success(url)
        defer { try? FileManager.default.removeItem(at: url) }

        var liveConfig = AppConfig()
        liveConfig.transcriptionEngine = "whisper"
        liveConfig.selectedDictationTemplate = .raw

        await whisper.setResult("Whisper output")
        await parakeet.setResult("Parakeet output")

        await MainActor.run {
            mode = DictationMode(
                recorder: recorder,
                transcriber: parakeet,
                inserter: inserter,
                configProvider: { liveConfig },
                transcriberResolver: { config in
                    config.transcriptionEngine == "parakeet" ? parakeet : whisper
                }
            )
        }

        await mode.startRecording()
        await mode.stopAndTranscribe()

        XCTAssertEqual(inserter.insertedTexts.first, "Whisper output")
        let whisperCalls = await whisper.sampleCallCount
        let parakeetCalls = await parakeet.sampleCallCount
        XCTAssertEqual(whisperCalls, 1)
        XCTAssertEqual(parakeetCalls, 0)
    }

    func testTranslateModeSkipsWhenResolvedEngineDoesNotSupportTranslation() async throws {
        let nonTranslatingEngine = MockTranscriber(supportsTranslation: false)
        let url = try makeWAVWithTone(seconds: 0.1)
        recorder.stopResult = .success(url)
        defer { try? FileManager.default.removeItem(at: url) }

        var liveConfig = AppConfig()
        liveConfig.transcriptionEngine = "parakeet"
        liveConfig.selectedDictationTemplate = .translate

        await MainActor.run {
            mode = DictationMode(
                recorder: recorder,
                transcriber: nonTranslatingEngine,
                inserter: inserter,
                configProvider: { liveConfig },
                transcriberResolver: { _ in nonTranslatingEngine }
            )
        }

        await mode.startRecording()
        await mode.stopAndTranscribe()

        XCTAssertTrue(inserter.insertedTexts.isEmpty)
        let callCount = await nonTranslatingEngine.sampleCallCount
        XCTAssertEqual(callCount, 0)
    }

    func testAskAIFallsBackToOriginalTextWhenLLMProcessorThrows() async throws {
        let url = try makeWAVWithTone(seconds: 0.1)
        recorder.stopResult = .success(url)
        defer { try? FileManager.default.removeItem(at: url) }

        var liveConfig = AppConfig()
        liveConfig.selectedDictationTemplate = .askAI
        liveConfig.llmProvider = "mlx"
        liveConfig.mlxModel = AppConfig.defaultMLXModelRepoID

        await transcriber.setResult("Onde fica o arquivo")

        await MainActor.run {
            mode = DictationMode(
                recorder: recorder,
                transcriber: transcriber,
                inserter: inserter,
                configProvider: { liveConfig },
                llmProcessor: { _, _, _, _ in
                    throw LLMError.mlxModelNotDownloaded(AppConfig.defaultMLXModelRepoID)
                }
            )
        }

        await mode.startRecording()
        await mode.stopAndTranscribe()

        XCTAssertEqual(inserter.insertedTexts.first, "Onde fica o arquivo")
        XCTAssertTrue(inserter.savedToClipboardTexts.isEmpty)
    }

    func testPlainDictationCopiesToClipboardWhenDirectPasteIsDisabled() async throws {
        let url = try makeWAVWithTone(seconds: 0.1)
        recorder.stopResult = .success(url)
        defer { try? FileManager.default.removeItem(at: url) }

        var liveConfig = AppConfig()
        liveConfig.selectedDictationTemplate = .raw
        liveConfig.plainDictationPasteDirectly = false

        await transcriber.setResult("Texto final do ditado")

        await MainActor.run {
            mode = DictationMode(
                recorder: recorder,
                transcriber: transcriber,
                inserter: inserter,
                configProvider: { liveConfig }
            )
        }

        await mode.startRecording()
        await mode.stopAndTranscribe()

        XCTAssertTrue(inserter.insertedTexts.isEmpty)
        XCTAssertEqual(inserter.savedToClipboardTexts, ["Texto final do ditado"])
    }
}

extension DictationModeTests {
    @MainActor
    func testRecordingKeepsInitialVocabularyButUsesCurrentGlobalRules() async throws {
        let url = try makeWAVWithTone(seconds: 0.1)
        recorder.stopResult = .success(url)
        defer { try? FileManager.default.removeItem(at: url) }
        await transcriber.setResult("Eu falo com Nico")
        var liveConfig = AppConfig()
        liveConfig.selectedDictationTemplate = .raw
        liveConfig.parakeetVocabularyTerms = [ParakeetVocabularyTerm(text: "Niko")]
        var observedTerms: [ParakeetVocabularyTerm] = []
        mode = DictationMode(
            recorder: recorder,
            transcriber: transcriber,
            inserter: inserter,
            configProvider: { liveConfig },
            transcriberResolver: { config in
                observedTerms = config.parakeetVocabularyTerms
                return self.transcriber
            }
        )
        await mode.startRecording()
        liveConfig.parakeetVocabularyTerms = [ParakeetVocabularyTerm(text: "Nicolau")]
        liveConfig.replacementRules = [ReplacementRule(variants: ["Nico"], replacement: "Nicolau")]
        await mode.stopAndTranscribe()
        XCTAssertEqual(observedTerms, [ParakeetVocabularyTerm(text: "Niko")])
        XCTAssertEqual(inserter.insertedTexts, ["Eu falo com Nicolau"])
    }

}

extension DictationModeTests {
    @MainActor
    func testSnapshotClearsOnSilentAndFailedStop() async throws {
        let audio = try makeSilentWAV()
        recorder.stopResult = .success(audio)
        await mode.startRecording()
        XCTAssertNotNil(mode.recordingVocabularyConfig)
        await mode.stopAndTranscribe()
        XCTAssertNil(mode.recordingVocabularyConfig)
        recorder.stopResult = .failure(VocabularyRecordingFailure.failed)
        await mode.startRecording()
        XCTAssertNotNil(mode.recordingVocabularyConfig)
        await mode.stopAndTranscribe()
        XCTAssertNil(mode.recordingVocabularyConfig)
    }

    @MainActor
    func testCancelledStartClearsSnapshotWithoutStartingAudio() async {
        let task = Task { await mode.startRecording() }
        task.cancel()
        await task.value
        XCTAssertEqual(recorder.startCallCount, 0)
        XCTAssertFalse(mode.isRecording)
        XCTAssertNil(mode.recordingVocabularyConfig)
    }

    @MainActor
    func testFailedStartClearsSnapshot() async {
        let failed = DictationMode(
            recorder: FailingVocabularyRecorder(), transcriber: transcriber, inserter: inserter, config: AppConfig()
        )
        await failed.startRecording()
        XCTAssertFalse(failed.isRecording)
        XCTAssertNil(failed.recordingVocabularyConfig)
    }
}

private enum VocabularyRecordingFailure: Error { case failed }

private struct FailingVocabularyRecorder: AudioRecording {
    func startRecording() throws { throw VocabularyRecordingFailure.failed }
    func stopRecording() throws -> URL { throw VocabularyRecordingFailure.failed }
    func setRMSHandler(_ handler: (@Sendable (Float) -> Void)?) {}
}

extension DictationModeTests {
    func testStartRecordingTriggersTranscriberPrewarm() async {
        let prewarmCalled = expectation(description: "transcriber prewarm")
        await MainActor.run {
            var config = AppConfig()
            config.selectedDictationTemplate = .raw
            mode = DictationMode(
                recorder: recorder, transcriber: transcriber, inserter: inserter, config: config,
                transcriberPrewarmer: { config in
                    await self.prewarmer.record(config: config)
                    prewarmCalled.fulfill()
                }
            )
        }
        await mode.startRecording()
        await fulfillment(of: [prewarmCalled], timeout: 1)
        let callCount = await prewarmer.callCount()
        let lastTemplate = await prewarmer.lastTemplate()
        XCTAssertEqual(callCount, 1)
        XCTAssertEqual(lastTemplate, .raw)
    }
}

private extension DictationModeTests {
    /// Creates a WAV with a 440 Hz tone (RMS well above 0.001 threshold).
    func makeWAVWithTone(seconds: Double = 0.05) throws -> URL {
        let sampleRate: Double = 16_000
        let format = try XCTUnwrap(
            AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)
        )
        let frameCount = AVAudioFrameCount(sampleRate * seconds)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount))
        buffer.frameLength = frameCount
        let data = try XCTUnwrap(buffer.floatChannelData?[0])
        for sample in 0..<Int(frameCount) {
            data[sample] = sin(2.0 * .pi * 440.0 * Float(sample) / Float(sampleRate)) * 0.5
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("dictmode_tone_\(UUID().uuidString).wav")
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }

    func makeSilentWAV(seconds: Double = 0.05) throws -> URL {
        let format = try XCTUnwrap(
            AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)
        )
        let frameCount = AVAudioFrameCount(16_000 * seconds)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount))
        buffer.frameLength = frameCount

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("dictmode_\(UUID().uuidString).wav")
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }
}
