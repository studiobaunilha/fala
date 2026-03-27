import AVFoundation
import XCTest
@testable import FalaCore

@MainActor
final class InsertionReviewPresenterSpy: InsertionReviewPresenting {
    private(set) var presentedTexts: [String] = []
    private(set) var dismissCallCount = 0

    func present(insertedText: String, using inserter: any TextInserting) {
        presentedTexts.append(insertedText)
    }

    func dismiss() {
        dismissCallCount += 1
    }
}

private extension InsertionReviewFlowTests {
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
            .appendingPathComponent("review_flow_\(UUID().uuidString).wav")
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }
}

@MainActor
final class InsertionReviewFlowTests: XCTestCase {
    func testDictationPresentsReviewBubbleAfterSuccessfulInsertion() async throws {
        let recorder = MockRecorder()
        let transcriber = MockTranscriber()
        let inserter = MockInserter()
        let reviewPresenter = InsertionReviewPresenterSpy()

        let url = try makeWAVWithTone(seconds: 0.1)
        recorder.stopResult = .success(url)
        defer { try? FileManager.default.removeItem(at: url) }

        await transcriber.setResult("Bonjour le monde")

        var config = AppConfig()
        config.selectedDictationTemplate = .raw

        let mode = DictationMode(
            recorder: recorder,
            transcriber: transcriber,
            inserter: inserter,
            config: config,
            insertionReviewPresenter: reviewPresenter
        )

        await mode.startRecording()
        await mode.stopAndTranscribe()

        XCTAssertEqual(inserter.insertedTexts.first, "Bonjour le monde")
        XCTAssertEqual(reviewPresenter.presentedTexts, ["Bonjour le monde"])
    }

    func testSelectionCommandPresentsReviewBubbleAfterDirectPaste() async throws {
        let recorder = MockRecorder()
        let transcriber = MockTranscriber()
        let inserter = MockInserter()
        let reviewPresenter = InsertionReviewPresenterSpy()

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
                "Texto com gramática corrigida"
            },
            insertionReviewPresenter: reviewPresenter
        )

        mode.setPendingSelectionForTesting("Texto com erro de gramatica")
        await mode.startRecording()
        await mode.stopAndTranscribe()

        XCTAssertEqual(inserter.insertedTexts.first, "Texto com gramática corrigida")
        XCTAssertEqual(
            reviewPresenter.presentedTexts,
            ["Texto com gramática corrigida"]
        )
    }
}
