import AppKit
import AVFoundation
import ApplicationServices

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController?
    private var dictationMode: DictationMode?
    private var settingsController: SettingsWindowController?
    private var transcribeController: TranscribeWindowController?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as a background app — no Dock icon.
        NSApp.setActivationPolicy(.accessory)

        let config = AppConfig.load()
        let transcriber = Transcriber(
            modelName: config.dictationModel,
            language: config.language,
            temperature: config.dictationTemperature,
            prompt: config.customDictionary.joined(separator: ", ")
        )
        let modelManager = ModelManager()
        modelManager.scanLocal()
        let appSettings = AppSettings(
            config: config,
            transcriber: transcriber,
            modelManager: modelManager
        )

        let settingsCtrl = SettingsWindowController(settings: appSettings)
        settingsController = settingsCtrl

        let job = TranscriptionJob()
        let transcribeCtrl = TranscribeWindowController(job: job)
        transcribeController = transcribeCtrl

        let bar = StatusBarController(
            onSettings: { settingsCtrl.show() },
            onTranscribe: { transcribeCtrl.show() }
        )
        let dictation = DictationMode(transcriber: transcriber, statusBar: bar)

        statusBar = bar
        dictationMode = dictation

        dictation.setup()

        // Request microphone access so macOS shows the prompt on first launch.
        requestMicrophoneAccess()

        // Request Accessibility access with a short delay so the app is fully
        // visible in the status bar before the system dialog appears.
        // Only prompts if not already trusted.
        if !AXIsProcessTrusted() {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 s
                AXIsProcessTrustedWithOptions(
                    ["AXTrustedCheckOptionPrompt": true] as CFDictionary
                )
            }
        }

        // Pre-load the model in the background so it's ready on first use.
        bar.setState(.loading)
        Task {
            do {
                NSLog("[Sussurro] Starting model pre-load: %@", config.dictationModel)
                try await transcriber.loadIfNeeded()
                NSLog("[Sussurro] Model pre-load succeeded")
            } catch {
                NSLog("[Sussurro] Model pre-load failed: %@", error.localizedDescription)
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
