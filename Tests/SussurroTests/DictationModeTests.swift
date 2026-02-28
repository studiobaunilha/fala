import XCTest
import AVFoundation
@testable import SussurroCore

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
}

/// Returns a fixed transcription string without loading any ML model.
actor MockTranscriber: AudioTranscribing {
    var transcribeResult: String = "Hello world"
    private(set) var sampleCallCount = 0

    func transcribe(samples: [Float]) async throws -> String {
        sampleCallCount += 1
        return transcribeResult
    }

    func transcribe(audioPath: String) async throws -> String {
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

    @MainActor func insert(_ text: String) {
        insertedTexts.append(text)
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
    // swiftlint:enable implicitly_unwrapped_optional

    override func setUp() {
        super.setUp()
        recorder    = MockRecorder()
        transcriber = MockTranscriber()
        inserter    = MockInserter()
        // DictationMode.init is @MainActor. XCTest runs setUp on the main
        // thread, so assumeIsolated is safe here.
        MainActor.assumeIsolated {
            mode = DictationMode(
                recorder: recorder,
                transcriber: transcriber,
                inserter: inserter
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
        let url = try makeSilentWAV(seconds: 0.1)
        recorder.stopResult = .success(url)
        defer { try? FileManager.default.removeItem(at: url) }

        await transcriber.setResult("Bonjour le monde")
        await mode.startRecording()
        await mode.stopAndTranscribe()

        XCTAssertFalse(inserter.insertedTexts.isEmpty)
        XCTAssertEqual(inserter.insertedTexts.first, "Bonjour le monde")
    }

    func testStopAndTranscribeDoesNotInsertEmptyText() async throws {
        let url = try makeSilentWAV(seconds: 0.1)
        recorder.stopResult = .success(url)
        defer { try? FileManager.default.removeItem(at: url) }

        await transcriber.setResult("")
        await mode.startRecording()
        await mode.stopAndTranscribe()

        XCTAssertTrue(inserter.insertedTexts.isEmpty)
    }

    func testStopAndTranscribeHandlesRecorderError() async {
        recorder.stopResult = .failure(AudioError.noRecording)

        await mode.startRecording()
        await mode.stopAndTranscribe() // must not crash

        XCTAssertTrue(inserter.insertedTexts.isEmpty)
    }

    // MARK: – Helpers

    private func makeSilentWAV(seconds: Double = 0.05) throws -> URL {
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
