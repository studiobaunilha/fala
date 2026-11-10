import XCTest
import AVFoundation
@testable import FalaCore

final class DictationReplacementPipelineTests: XCTestCase, @unchecked Sendable {
    @MainActor
    func testSuccessfulAICleanupKeepsConfiguredNameCorrectionInInsertedText() async throws {
        let recorder = MockRecorder()
        let transcriber = MockTranscriber()
        let inserter = MockInserter()
        let audioURL = try makeTone()
        recorder.stopResult = .success(audioURL)
        defer { try? FileManager.default.removeItem(at: audioURL) }

        var config = AppConfig()
        config.selectedDictationTemplate = .custom
        config.customModePrompt = "Keep the text and add a period."
        config.llmProvider = "mlx"
        config.replacementRules = [ReplacementRule(variants: ["Nico"], replacement: "Niko")]
        let mode = DictationMode(
            recorder: recorder,
            transcriber: transcriber,
            inserter: inserter,
            config: config,
            llmProcessor: { _, _, _, _ in "Eu comunico com Nico." }
        )

        await transcriber.setResult("Eu comunico com Nico")
        await mode.startRecording()
        await mode.stopAndTranscribe()

        XCTAssertEqual(inserter.insertedTexts, ["Eu comunico com Niko."])
    }

    @MainActor
    func testAIEchoDoesNotApplyAChainOfRulesTwice() async throws {
        let recorder = MockRecorder()
        let transcriber = MockTranscriber()
        let inserter = MockInserter()
        let audioURL = try makeTone()
        recorder.stopResult = .success(audioURL)
        defer { try? FileManager.default.removeItem(at: audioURL) }

        var config = AppConfig()
        config.selectedDictationTemplate = .custom
        config.customModePrompt = "Keep the text and add a period."
        config.llmProvider = "mlx"
        config.replacementRules = [
            ReplacementRule(variants: ["Nico"], replacement: "Niko"),
            ReplacementRule(variants: ["Niko"], replacement: "Nicolau")
        ]
        let mode = DictationMode(
            recorder: recorder,
            transcriber: transcriber,
            inserter: inserter,
            config: config,
            llmProcessor: { text, _, _, _ in text + "." }
        )

        await transcriber.setResult("Eu comunico com Nico")
        await mode.startRecording()
        await mode.stopAndTranscribe()

        XCTAssertEqual(inserter.insertedTexts, ["Eu comunico com Niko."])
    }

    private func makeTone() throws -> URL {
        let sampleRate: Double = 16_000
        let format = try XCTUnwrap(AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false
        ))
        let frames: AVAudioFrameCount = 1_600
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
        buffer.frameLength = frames
        let samples = try XCTUnwrap(buffer.floatChannelData?[0])
        for index in 0..<Int(frames) {
            samples[index] = 0.5 * sin(2 * .pi * 440 * Float(index) / Float(sampleRate))
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("dictation-replacement-\(UUID().uuidString).wav")
        try AVAudioFile(forWriting: url, settings: format.settings).write(from: buffer)
        return url
    }
}
