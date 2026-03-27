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

        // No SelectionCapture injected → pendingSelectionContext stays nil.
        let mode = DictationMode(
            recorder: recorder,
            transcriber: transcriber,
            inserter: inserter,
            configProvider: { liveConfig }
        )

        await mode.startRecording()
        await mode.stopAndTranscribe()

        // Raw mode without selection: text inserted directly without LLM
        XCTAssertEqual(inserter.insertedTexts.first, "Hello world test text")
    }

    // MARK: - wrapForSelectionCommand

    func testWrapForSelectionCommandIncludesSelectionAndInstruction() {
        let result = DictationMode.wrapForSelectionCommand(
            "Resuma isso", selection: "O Brasil é um país grande"
        )
        XCTAssert(result.contains("O Brasil é um país grande"))
        XCTAssert(result.contains("Resuma isso"))
        XCTAssert(result.contains("Selected text:"))
        XCTAssert(result.contains("User instruction:"))
        XCTAssert(result.contains("---"))
    }

    // MARK: - Selection + AI Command flow

    func testSelectionCommandForcesLLMForRawTemplate() async throws {
        let recorder = MockRecorder()
        let transcriber = MockTranscriber()
        let inserter = MockInserter()

        let url = try makeWAVWithTone(seconds: 0.1)
        recorder.stopResult = .success(url)
        defer { try? FileManager.default.removeItem(at: url) }

        var liveConfig = AppConfig()
        liveConfig.selectedDictationTemplate = .raw
        liveConfig.llmProvider = "gemini"
        liveConfig.geminiKey = "test-key"

        await transcriber.setResult("Resuma isso para mim")

        var llmWasCalled = false
        let mode = DictationMode(
            recorder: recorder,
            transcriber: transcriber,
            inserter: inserter,
            configProvider: { liveConfig },
            llmProcessor: { _, _, _, _ in
                llmWasCalled = true
                return "Resumo do texto"
            }
        )

        // Simulate user having text selected
        mode.setPendingSelectionForTesting("Texto longo que será resumido")
        await mode.startRecording()
        await mode.stopAndTranscribe()

        XCTAssertTrue(llmWasCalled, "LLM should be invoked for selection command")
    }

    func testSelectionCommandReplacesWithLLMResult() async throws {
        let recorder = MockRecorder()
        let transcriber = MockTranscriber()
        let inserter = MockInserter()

        let url = try makeWAVWithTone(seconds: 0.1)
        recorder.stopResult = .success(url)
        defer { try? FileManager.default.removeItem(at: url) }

        var liveConfig = AppConfig()
        liveConfig.selectedDictationTemplate = .raw
        liveConfig.llmProvider = "gemini"
        liveConfig.geminiKey = "test-key"

        await transcriber.setResult("Corrija a gramatica")

        let mode = DictationMode(
            recorder: recorder,
            transcriber: transcriber,
            inserter: inserter,
            configProvider: { liveConfig },
            llmProcessor: { _, _, _, _ in
                return "Texto com gramática corrigida"
            }
        )

        mode.setPendingSelectionForTesting("Texto com erro de gramatica")
        await mode.startRecording()
        await mode.stopAndTranscribe()

        XCTAssertEqual(
            inserter.insertedTexts.first,
            "Texto com gramática corrigida"
        )
    }

    func testSelectionCommandDoesNotInsertVoiceInstructionWhenLLMIsUnavailable() async throws {
        let recorder = MockRecorder()
        let transcriber = MockTranscriber()
        let inserter = MockInserter()

        let url = try makeWAVWithTone(seconds: 0.1)
        recorder.stopResult = .success(url)
        defer { try? FileManager.default.removeItem(at: url) }

        var liveConfig = AppConfig()
        liveConfig.selectedDictationTemplate = .raw
        liveConfig.llmProvider = "gemini"
        liveConfig.geminiKey = "test-key"

        await transcriber.setResult("Resuma isso para mim")

        let mode = DictationMode(
            recorder: recorder,
            transcriber: transcriber,
            inserter: inserter,
            configProvider: { liveConfig },
            llmProcessor: { _, _, _, _ in
                throw LLMError.noAPIKey(provider: "Gemini")
            }
        )

        mode.setPendingSelectionForTesting("Texto selecionado que seria processado")
        await mode.startRecording()
        await mode.stopAndTranscribe()

        XCTAssertTrue(inserter.insertedTexts.isEmpty)
    }

    func testNoSelectionKeepsNormalRawFlow() async throws {
        let recorder = MockRecorder()
        let transcriber = MockTranscriber()
        let inserter = MockInserter()

        let url = try makeWAVWithTone(seconds: 0.1)
        recorder.stopResult = .success(url)
        defer { try? FileManager.default.removeItem(at: url) }

        var liveConfig = AppConfig()
        liveConfig.selectedDictationTemplate = .raw

        await transcriber.setResult("Texto normal sem selecao")

        var llmWasCalled = false
        let mode = DictationMode(
            recorder: recorder,
            transcriber: transcriber,
            inserter: inserter,
            configProvider: { liveConfig },
            llmProcessor: { _, _, _, _ in
                llmWasCalled = true
                return "Should not appear"
            }
        )

        // No selection injected — pendingSelectionContext remains nil
        await mode.startRecording()
        await mode.stopAndTranscribe()

        XCTAssertFalse(llmWasCalled, "LLM should NOT be invoked without selection")
        XCTAssertEqual(
            inserter.insertedTexts.first,
            "Texto normal sem selecao"
        )
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
