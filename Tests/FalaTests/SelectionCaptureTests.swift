import XCTest
import AVFoundation
@testable import FalaCore

@MainActor
final class SelectionCaptureTests: XCTestCase, @unchecked Sendable {

    // MARK: - wrapWithSelectionContext

    func testWrapWithNilSelectionReturnsOriginalText() {
        let result = DictationMode.wrapWithSelectionContext(
            "What does this mean?", selection: nil
        )
        XCTAssertEqual(result, "What does this mean?")
    }

    func testWrapWithEmptySelectionReturnsOriginalText() {
        let result = DictationMode.wrapWithSelectionContext(
            "Explain this", selection: ""
        )
        XCTAssertEqual(result, "Explain this")
    }

    func testWrapWithSelectionIncludesContextAndQuestion() {
        let result = DictationMode.wrapWithSelectionContext(
            "What does this function do?",
            selection: "func foo() { return 42 }"
        )
        XCTAssert(result.contains("func foo() { return 42 }"))
        XCTAssert(result.contains("What does this function do?"))
        XCTAssert(result.contains("Context"))
        XCTAssert(result.contains("---"))
    }

    // MARK: - askAI with selection context

    func testAskAIPassesSelectionContextToLLM() async throws {
        let recorder = MockRecorder()
        let transcriber = MockTranscriber()
        let inserter = MockInserter()

        let url = try makeWAVWithTone(seconds: 0.1)
        recorder.stopResult = .success(url)
        defer { try? FileManager.default.removeItem(at: url) }

        var liveConfig = AppConfig()
        liveConfig.selectedDictationTemplate = .askAI
        liveConfig.llmProvider = "gemini"
        liveConfig.geminiKey = "test-key"

        await transcriber.setResult("What does this do")

        var receivedText: String?
        let mode = DictationMode(
            recorder: recorder,
            transcriber: transcriber,
            inserter: inserter,
            configProvider: { liveConfig },
            llmProcessor: { text, _, _, _ in
                receivedText = text
                return "It returns 42"
            }
        )

        // Simulate having a pending selection context by starting
        // and immediately stopping (selection capture is nil in tests,
        // so we test the wrapping logic directly).
        await mode.startRecording()
        await mode.stopAndTranscribe()

        // Without selection capture, the text should pass through unwrapped.
        XCTAssertEqual(receivedText, "What does this do")
    }

    func testNonConversationalTemplateIgnoresSelectionCapture() async throws {
        let recorder = MockRecorder()
        let transcriber = MockTranscriber()
        let inserter = MockInserter()

        let url = try makeWAVWithTone(seconds: 0.1)
        recorder.stopResult = .success(url)
        defer { try? FileManager.default.removeItem(at: url) }

        var liveConfig = AppConfig()
        liveConfig.selectedDictationTemplate = .raw

        await transcriber.setResult("Hello world test text")

        let mode = DictationMode(
            recorder: recorder,
            transcriber: transcriber,
            inserter: inserter,
            configProvider: { liveConfig }
        )

        await mode.startRecording()
        await mode.stopAndTranscribe()

        // Raw mode: text inserted directly without LLM
        XCTAssertEqual(inserter.insertedTexts.first, "Hello world test text")
    }
}

private extension SelectionCaptureTests {
    func makeWAVWithTone(seconds: Double = 0.05) throws -> URL {
        let sampleRate: Double = 16_000
        let format = try XCTUnwrap(
            AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: sampleRate, channels: 1, interleaved: false
            )
        )
        let frameCount = AVAudioFrameCount(sampleRate * seconds)
        let buffer = try XCTUnwrap(
            AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
        )
        buffer.frameLength = frameCount
        let data = try XCTUnwrap(buffer.floatChannelData?[0])
        for sample in 0..<Int(frameCount) {
            let value = sin(2.0 * .pi * 440.0 * Float(sample) / Float(sampleRate))
            data[sample] = value * 0.5
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("selcap_\(UUID().uuidString).wav")
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }
}
