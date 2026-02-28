import KeyboardShortcuts
import Foundation

/// Orchestrates the push-to-talk flow:
/// keyDown → start recording → keyUp → transcribe → insert text.
///
/// All dependencies are injected via protocols so that DictationMode can be
/// unit-tested without real audio hardware, ML models, or Accessibility access.
@MainActor
public final class DictationMode {
    private let recorder: any AudioRecording
    private let transcriber: any AudioTranscribing
    private let inserter: any TextInserting
    private weak var statusBar: StatusBarController?

    private var isRecording = false

    /// Production initialiser — uses real concrete implementations.
    public convenience init(transcriber: Transcriber, statusBar: StatusBarController) {
        self.init(
            recorder: AudioEngine(),
            transcriber: transcriber,
            inserter: TextInserter(),
            statusBar: statusBar
        )
    }

    /// Designated initialiser — accepts protocol abstractions for testability.
    public init(
        recorder: any AudioRecording,
        transcriber: any AudioTranscribing,
        inserter: any TextInserting,
        statusBar: StatusBarController? = nil
    ) {
        self.recorder = recorder
        self.transcriber = transcriber
        self.inserter = inserter
        self.statusBar = statusBar
    }

    /// Binds global keyboard shortcut handlers. Call once at app startup.
    public func setup() {
        KeyboardShortcuts.onKeyDown(for: .startDictation) { [weak self] in
            guard let self, !self.isRecording else { return }
            Task { @MainActor in await self.startRecording() }
        }

        KeyboardShortcuts.onKeyUp(for: .startDictation) { [weak self] in
            guard let self, self.isRecording else { return }
            Task { @MainActor in await self.stopAndTranscribe() }
        }
    }

    // MARK: – Internal (accessible from tests via @testable import)

    func startRecording() async {
        guard !isRecording else { return }
        do {
            try recorder.startRecording()
            isRecording = true
            statusBar?.setState(.recording)
        } catch {
            print("[Sussurro] Recording start failed: \(error.localizedDescription)")
        }
    }

    func stopAndTranscribe() async {
        isRecording = false
        statusBar?.setState(.transcribing)

        do {
            let audioURL = try recorder.stopRecording()
            defer { try? FileManager.default.removeItem(at: audioURL) }

            let samples = try AudioConverter.toFloat16k(from: audioURL)
            guard !samples.isEmpty else {
                statusBar?.setState(.idle)
                return
            }

            let text = try await transcriber.transcribe(samples: samples)
            if !text.isEmpty {
                inserter.insert(text)
            }
        } catch {
            print("[Sussurro] Transcription error: \(error.localizedDescription)")
        }

        statusBar?.setState(.idle)
    }
}
