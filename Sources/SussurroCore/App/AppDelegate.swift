import AppKit
import AVFoundation
import ApplicationServices

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController?
    private var dictationMode: DictationMode?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as a background app — no Dock icon.
        NSApp.setActivationPolicy(.accessory)

        let config = AppConfig.load()
        let bar = StatusBarController()
        let transcriber = Transcriber(modelName: config.dictationModel)
        let dictation = DictationMode(transcriber: transcriber, statusBar: bar)

        statusBar = bar
        dictationMode = dictation

        dictation.setup()

        // Request microphone access so macOS shows the prompt on first launch.
        // Accessibility (for text insertion) is requested lazily when the hotkey
        // is first used — calling AXIsProcessTrustedWithOptions at startup can
        // crash on macOS Tahoe when the process has no bundle context.
        requestMicrophoneAccess()

        // Pre-load the model in the background so it's ready on first use.
        bar.setState(.loading)
        Task {
            do {
                try await transcriber.loadIfNeeded()
            } catch {
                print("[Sussurro] Model pre-load failed: \(error.localizedDescription)")
            }
            bar.setState(.idle)
        }
    }

    private func requestMicrophoneAccess() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                if !granted {
                    print("[Sussurro] Microphone access denied.")
                }
            }
        case .denied, .restricted:
            print("[Sussurro] Microphone access denied. Enable in System Settings → Privacy → Microphone.")
        @unknown default:
            break
        }
    }
}
