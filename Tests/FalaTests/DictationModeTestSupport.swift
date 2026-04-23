import XCTest
@testable import FalaCore

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

    func setRMSHandler(_ handler: (@Sendable (Float) -> Void)?) {}
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
        if let progress {
            progress(TranscriberProgress(text: transcribeResult, windowId: 0))
        }
        return transcribeResult
    }

    func setResult(_ text: String) {
        transcribeResult = text
    }
}

/// Records insert calls without touching NSPasteboard or CGEventPost.
/// @unchecked Sendable: state is only accessed from @MainActor test flows.
final class MockInserter: TextInserting, @unchecked Sendable {
    private(set) var insertedTexts: [String] = []
    private(set) var savedToClipboardTexts: [String] = []
    private(set) var undoCallCount = 0
    private(set) var replacedTexts: [String] = []

    @MainActor func insert(_ text: String) async {
        insertedTexts.append(text)
    }

    @MainActor func saveToClipboard(_ text: String) {
        savedToClipboardTexts.append(text)
    }

    @MainActor func undoLastInsertion() async {
        undoCallCount += 1
    }

    @MainActor func replaceLastInsertion(with text: String) async {
        replacedTexts.append(text)
    }
}

actor DictationPrewarmerSpy {
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
