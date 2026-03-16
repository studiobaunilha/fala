import XCTest
import AVFoundation
@testable import FalaCore

// MARK: – Mocks

/// Records which calls were made without touching real hardware.
final class MockRecorder: AudioRecording, @unchecked Sendable {
    private(set) var startCallCount = 0
    private(set) var stopCallCount  = 0
    var stopResult: Result<URL, Error> = .success(
        FileManager.default.temporaryDirectory.appendingPathComponent("mock_audio.wav")
    )

    func startRecording() throws {
        startCallCount += 1
    }

    func stopRecording() throws -> URL {
        stopCallCount += 1
        return try stopResult.get()
    }

    func setRMSHandler(_ handler: (@Sendable (Float) -> Void)?) {
        // No-op in tests
    }
}

/// Returns a fixed transcription string without loading any ML model.
actor MockTranscriber: AudioTranscribing {
    var transcribeResult: String = "Hello world"
    let supportsTranslation: Bool
    private(set) var sampleCallCount = 0

    init(supportsTranslation: Bool = true) {
        self.supportsTranslation = supportsTranslation
    }

    func transcribe(samples: [Float], task: String) async throws -> String {
        sampleCallCount += 1
        return transcribeResult
    }

    func transcribe(
        audioPath: String,
        task: String,
        progress: (@Sendable (TranscriberProgress) -> Void)? = nil
    ) async throws -> String {
        if let progress { progress(TranscriberProgress(text: transcribeResult, windowId: 0)) }
        return transcribeResult
    }

    func setResult(_ text: String) {
        transcribeResult = text
    }
}

/// Records insert calls without touching NSPasteboard or CGEventPost.
/// @unchecked Sendable: insertedTexts is only ever accessed from @MainActor context.
final class MockInserter: TextInserting, @unchecked Sendable {
    private(set) var insertedTexts: [String] = []
    private(set) var savedToClipboardTexts: [String] = []

    @MainActor func insert(_ text: String) async {
        insertedTexts.append(text)
    }

    @MainActor func saveToClipboard(_ text: String) {
        savedToClipboardTexts.append(text)
    }
}

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
            LicenseManager.shared.setTestActivated(true)
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

    func testStartRecordingTriggersTranscriberPrewarm() async {
        let waitTask = Task {
            await prewarmer.waitForFirstCall()
        }
        await mode.startRecording()
        await waitTask.value

        let callCount = await prewarmer.callCount()
        let lastTemplate = await prewarmer.lastTemplate()

        XCTAssertEqual(callCount, 1)
        XCTAssertEqual(lastTemplate, .raw)
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
        XCTAssertEqual(inserter.savedToClipboardTexts.first, "Onde fica o arquivo")
    }

}

private actor DictationPrewarmerSpy {
    private var configs: [AppConfig] = []
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func record(config: AppConfig) {
        configs.append(config)
        let continuations = waiters
        waiters.removeAll()
        for continuation in continuations {
            continuation.resume()
        }
    }

    func callCount() -> Int {
        configs.count
    }

    func lastTemplate() -> DictationTemplate? {
        configs.last?.selectedDictationTemplate
    }

    func waitForFirstCall() async {
        guard configs.isEmpty else {
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
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
