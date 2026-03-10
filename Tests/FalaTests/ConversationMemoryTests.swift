import XCTest
import AVFoundation
@testable import FalaCore

@MainActor
final class ConversationMemoryTests: XCTestCase {

    func testAppendAddsUserAndAssistantTurns() {
        let memory = ConversationMemory()
        memory.append(userText: "Olá", assistantResponse: "Oi!")
        XCTAssertEqual(memory.turns.count, 2)
        XCTAssertEqual(memory.turns[0].role, "user")
        XCTAssertEqual(memory.turns[0].content, "Olá")
        XCTAssertEqual(memory.turns[1].role, "assistant")
        XCTAssertEqual(memory.turns[1].content, "Oi!")
    }

    func testTurnCountReflectsQAPairs() {
        let memory = ConversationMemory()
        memory.append(userText: "Q1", assistantResponse: "A1")
        memory.append(userText: "Q2", assistantResponse: "A2")
        XCTAssertEqual(memory.turnCount, 2)
    }

    func testHasHistoryIsFalseWhenEmpty() {
        let memory = ConversationMemory()
        XCTAssertFalse(memory.hasHistory)
    }

    func testHasHistoryIsTrueAfterAppend() {
        let memory = ConversationMemory()
        memory.append(userText: "Q", assistantResponse: "A")
        XCTAssertTrue(memory.hasHistory)
    }

    func testClearRemovesAllTurns() {
        let memory = ConversationMemory()
        memory.append(userText: "Q", assistantResponse: "A")
        memory.clear()
        XCTAssertFalse(memory.hasHistory)
        XCTAssertEqual(memory.turns.count, 0)
    }

    func testTrimsToMaxTurns() {
        let memory = ConversationMemory(maxTurns: 4)
        memory.append(userText: "Q1", assistantResponse: "A1")
        memory.append(userText: "Q2", assistantResponse: "A2")
        memory.append(userText: "Q3", assistantResponse: "A3")
        // maxTurns=4 → keeps last 2 pairs
        XCTAssertEqual(memory.turns.count, 4)
        XCTAssertEqual(memory.turns[0].content, "Q2")
        XCTAssertEqual(memory.turns[3].content, "A3")
    }

    func testMessagesForAPIReturnsCorrectFormat() {
        let memory = ConversationMemory()
        memory.append(userText: "What is 2+2?", assistantResponse: "4")
        let messages = memory.messagesForAPI()
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0], ["role": "user", "content": "What is 2+2?"])
        XCTAssertEqual(messages[1], ["role": "assistant", "content": "4"])
    }

    func testContextSummaryFormatsCorrectly() {
        let memory = ConversationMemory()
        memory.append(userText: "Hi", assistantResponse: "Hello")
        let summary = memory.contextSummary
        XCTAssertTrue(summary.contains("User: Hi"))
        XCTAssertTrue(summary.contains("Assistant: Hello"))
    }

    func testContextSummaryIsEmptyWhenNoHistory() {
        let memory = ConversationMemory()
        XCTAssertEqual(memory.contextSummary, "")
    }

    func testInactivityTimeoutResetsMemory() {
        let memory = ConversationMemory(inactivityTimeout: 0.01)
        memory.append(userText: "Q", assistantResponse: "A")
        Thread.sleep(forTimeInterval: 0.02)
        let messages = memory.messagesForAPI()
        XCTAssertTrue(messages.isEmpty)
        XCTAssertFalse(memory.hasHistory)
    }

    func testNoResetBeforeTimeout() {
        let memory = ConversationMemory(inactivityTimeout: 60)
        memory.append(userText: "Q", assistantResponse: "A")
        let messages = memory.messagesForAPI()
        XCTAssertEqual(messages.count, 2)
    }

    func testContextKeyChangeResetsMemory() {
        let memory = ConversationMemory()
        memory.append(userText: "Q1", assistantResponse: "A1", contextKey: "askAI::openai")
        XCTAssertEqual(memory.turnCount, 1)
        // Same key preserves history
        memory.append(userText: "Q2", assistantResponse: "A2", contextKey: "askAI::openai")
        XCTAssertEqual(memory.turnCount, 2)
        // Different key resets before appending
        memory.append(userText: "Q3", assistantResponse: "A3", contextKey: "askAI::gemini")
        XCTAssertEqual(memory.turnCount, 1)
        XCTAssertEqual(memory.turns[0].content, "Q3")
    }

    func testNilContextKeyDoesNotReset() {
        let memory = ConversationMemory()
        memory.append(userText: "Q1", assistantResponse: "A1", contextKey: "askAI::mlx")
        memory.append(userText: "Q2", assistantResponse: "A2")
        XCTAssertEqual(memory.turnCount, 2)
    }

    // MARK: - DictationMode Integration

    func testAskAISavesToConversationMemory() async throws {
        let fix = makeDictationMode(
            template: .askAI,
            llmProcessor: { _, _, _, _ in "Paris is the capital." }
        )
        let url = try makeWAVWithTone()
        fix.recorder.stopResult = .success(url)
        defer { try? FileManager.default.removeItem(at: url) }

        await fix.transcriber.setResult("What is the capital of France")
        await fix.mode.startRecording()
        await fix.mode.stopAndTranscribe()

        XCTAssertEqual(fix.mode.conversationMemory.turnCount, 1)
        let msgs = fix.mode.conversationMemory.messagesForAPI()
        XCTAssertEqual(msgs[0]["content"], "What is the capital of France")
        XCTAssertEqual(msgs[1]["content"], "Paris is the capital.")
    }

    func testNonConversationalDoesNotSaveToMemory() async throws {
        let fix = makeDictationMode(
            template: .custom,
            llmProcessor: { _, _, _, _ in "Processed." }
        )
        let url = try makeWAVWithTone()
        fix.recorder.stopResult = .success(url)
        defer { try? FileManager.default.removeItem(at: url) }

        await fix.transcriber.setResult("Some dictated text here now")
        await fix.mode.startRecording()
        await fix.mode.stopAndTranscribe()

        XCTAssertEqual(fix.mode.conversationMemory.turnCount, 0)
    }
}

// MARK: - Helpers

private extension ConversationMemoryTests {
    struct TestFixture {
        let mode: DictationMode
        let transcriber: MockTranscriber
        let recorder: MockRecorder
    }

    func makeDictationMode(
        template: DictationTemplate,
        llmProcessor: @escaping DictationMode.LLMProcessor
    ) -> TestFixture {
        let recorder = MockRecorder()
        let transcriber = MockTranscriber()
        let inserter = MockInserter()
        var config = AppConfig()
        config.selectedDictationTemplate = template
        config.llmProvider = "openai"
        config.openAIKey = "test-key"
        LicenseManager.shared.setTestActivated(true)
        let mode = DictationMode(
            recorder: recorder,
            transcriber: transcriber,
            inserter: inserter,
            config: config,
            llmProcessor: llmProcessor
        )
        return TestFixture(mode: mode, transcriber: transcriber, recorder: recorder)
    }

    func makeWAVWithTone(seconds: Double = 0.1) throws -> URL {
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
            data[sample] = sin(2.0 * .pi * 440.0 * Float(sample) / Float(sampleRate)) * 0.5
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("convmem_\(UUID().uuidString).wav")
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }
}
