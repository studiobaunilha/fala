import XCTest
@testable import FalaCore

@MainActor
final class VocabularyRecordingOwnershipTests: XCTestCase {
    func testResumedOldCaptureCannotPublishSelectionOrStartAudioForNewRecording() async {
        let firstCapture = expectation(description: "first capture suspended")
        let secondCapture = expectation(description: "second capture suspended")
        let gate = RecordingCaptureGate(first: firstCapture, second: secondCapture)
        let recorder = MockRecorder()
        recorder.stopResult = .failure(RecordingOwnershipError.noAudio)
        let mode = DictationMode(
            recorder: recorder, transcriber: MockTranscriber(), inserter: MockInserter(), config: AppConfig(),
            selectionCapturer: { await gate.capture() }
        )
        let firstTask = Task { await mode.startRecording() }
        var secondTask: Task<Void, Never>?
        defer {
            gate.releaseAll()
            firstTask.cancel()
            secondTask?.cancel()
        }
        await fulfillment(of: [firstCapture], timeout: 1)
        guard gate.calls == 1 else { return }
        await mode.stopAndTranscribe()
        secondTask = Task { await mode.startRecording() }
        await fulfillment(of: [secondCapture], timeout: 1)
        guard gate.calls == 2 else { return }
        gate.release(1, selection: "A selection")
        await firstTask.value
        XCTAssertEqual(recorder.startCallCount, 0, "A retired capture cannot act on the next recording")
        XCTAssertNil(mode.pendingSelectionContext, "A retired capture cannot publish selection into the next recording")
        gate.release(2, selection: "B selection")
        await secondTask?.value
        XCTAssertEqual(recorder.startCallCount, 1)
        XCTAssertEqual(mode.pendingSelectionContext, "B selection")
    }
}

private enum RecordingOwnershipError: Error { case noAudio }

@MainActor
private final class RecordingCaptureGate {
    private let first: XCTestExpectation
    private let second: XCTestExpectation
    private var continuations: [Int: CheckedContinuation<String?, Never>] = [:]
    private var closed = false
    private(set) var calls = 0

    init(first: XCTestExpectation, second: XCTestExpectation) {
        self.first = first
        self.second = second
    }

    func capture() async -> String? {
        guard !closed else { return nil }
        calls += 1
        let call = calls
        return await withCheckedContinuation { continuation in
            continuations[call] = continuation
            (call == 1 ? first : second).fulfill()
        }
    }

    func release(_ call: Int, selection: String? = nil) {
        continuations.removeValue(forKey: call)?.resume(returning: selection)
    }

    func releaseAll() {
        closed = true
        let pending = continuations.values
        continuations.removeAll()
        for continuation in pending { continuation.resume(returning: nil) }
    }
}
