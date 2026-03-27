import AVFoundation
import XCTest
@testable import FalaCore

private extension SelectionCommandPromptTests {
    func makeWAVWithTone(seconds: Double = 0.05) throws -> URL {
        let sampleRate: Double = 16_000
        let format = try XCTUnwrap(
            AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: sampleRate,
                channels: 1,
                interleaved: false
            )
        )
        let frameCount = AVAudioFrameCount(sampleRate * seconds)
        let buffer = try XCTUnwrap(
            AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: frameCount
            )
        )
        buffer.frameLength = frameCount
        let data = try XCTUnwrap(buffer.floatChannelData?[0])
        for sample in 0..<Int(frameCount) {
            data[sample] = sin(
                2.0 * .pi * 440.0 * Float(sample) / Float(sampleRate)
            ) * 0.5
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("selection_prompt_\(UUID().uuidString).wav")
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }
}

@MainActor
final class SelectionCommandPromptTests: XCTestCase {
    func testSelectionCommandUsesDedicatedSelectionPromptConfig() async throws {
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
        liveConfig.selectionCommandConfig = SelectionCommandConfig(
            prompt: "Prompt dedicado de seleção"
        )

        await transcriber.setResult("Corrija a gramatica")

        var receivedPrompt: String?
        let mode = DictationMode(
            recorder: recorder,
            transcriber: transcriber,
            inserter: inserter,
            configProvider: { liveConfig },
            llmProcessor: { _, prompt, _, _ in
                receivedPrompt = prompt
                return "Texto com gramática corrigida"
            }
        )

        mode.setPendingSelectionForTesting("Texto com erro de gramatica")
        await mode.startRecording()
        await mode.stopAndTranscribe()

        XCTAssertEqual(receivedPrompt, "Prompt dedicado de seleção")
    }

    func testSelectionCommandTakesPriorityOverCustomModeWhenTextIsSelected() async throws {
        let recorder = MockRecorder()
        let transcriber = MockTranscriber()
        let inserter = MockInserter()

        let url = try makeWAVWithTone(seconds: 0.1)
        recorder.stopResult = .success(url)
        defer { try? FileManager.default.removeItem(at: url) }

        var liveConfig = AppConfig()
        liveConfig.selectedDictationTemplate = .custom
        liveConfig.llmProvider = "gemini"
        liveConfig.geminiKey = "test-key"
        liveConfig.customModePrompt = "Prompt do modo personalizado"
        liveConfig.selectionCommandConfig = SelectionCommandConfig(
            prompt: "Prompt dedicado de seleção"
        )

        await transcriber.setResult("Resuma isso")

        var receivedPrompt: String?
        let mode = DictationMode(
            recorder: recorder,
            transcriber: transcriber,
            inserter: inserter,
            configProvider: { liveConfig },
            llmProcessor: { _, prompt, _, _ in
                receivedPrompt = prompt
                return "Resumo final"
            }
        )

        mode.setPendingSelectionForTesting("Texto longo selecionado")
        await mode.startRecording()
        await mode.stopAndTranscribe()

        XCTAssertEqual(receivedPrompt, "Prompt dedicado de seleção")
        XCTAssertEqual(inserter.insertedTexts.first, "Resumo final")
    }
}
