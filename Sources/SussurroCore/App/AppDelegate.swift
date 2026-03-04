import AppKit
import AVFoundation
import ApplicationServices

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController?
    private var dictationMode: DictationMode?
    private var settingsController: SettingsWindowController?
    private var transcribeController: TranscribeWindowController?
    private var feedbackController: DictationFeedbackController?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as a background app — no Dock icon.
        NSApp.setActivationPolicy(.accessory)

        let config = AppConfig.load()
        let whisperTranscriber = Transcriber(
            modelName: config.dictationModel,
            language: config.language,
            temperature: config.dictationTemperature,
            prompt: ""
        )
        let modelManager = ModelManager()
        modelManager.scanLocal()
        let appSettings = AppSettings(
            config: config,
            transcriber: whisperTranscriber,
            modelManager: modelManager
        )

        let settingsCtrl = SettingsWindowController(settings: appSettings)
        settingsController = settingsCtrl

        let transcribeCtrl = TranscribeWindowController(settings: appSettings)
        transcribeController = transcribeCtrl

        let bar = StatusBarController(
            settings: appSettings,
            onSettings: { settingsCtrl.show() },
            onTranscribe: { transcribeCtrl.show() }
        )

        let activeTranscriber: any AudioTranscribing = config.transcriptionEngine == "parakeet"
            ? ParakeetTranscriber()
            : whisperTranscriber

        let feedbackCtrl = DictationFeedbackController()
        feedbackController = feedbackCtrl

        let dictation = DictationMode(
            recorder: AudioEngine(),
            transcriber: activeTranscriber,
            inserter: TextInserter(),
            statusBar: bar,
            feedback: feedbackCtrl
        )

        statusBar = bar
        dictationMode = dictation

        dictation.setup()
        requestMicrophoneAccess()
        requestAccessibilityAccess()
        preloadModel(config: config, transcriber: activeTranscriber, whisper: whisperTranscriber, bar: bar)
    }

    private func requestAccessibilityAccess() {
        guard !AXIsProcessTrusted() else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 s
            AXIsProcessTrustedWithOptions(
                ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            )
        }
    }

    private func preloadModel(
        config: AppConfig,
        transcriber: any AudioTranscribing,
        whisper: Transcriber,
        bar: StatusBarController
    ) {
        bar.setState(.loading)
        Task {
            do {
                let name = config.transcriptionEngine == "parakeet"
                    ? "Parakeet V3" : config.dictationModel
                    
                let progressHandler: @Sendable (Double) -> Void = { [weak bar] fraction in
                    Task { @MainActor in
                        bar?.setDownloadProgress(fraction, modelName: name)
                    }
                }
                
                bar.setLoadingTooltip("Carregando modelo \(name)…")
                NSLog("[Sussurro] Starting model pre-load: %@", name)
                if let parakeet = transcriber as? ParakeetTranscriber {
                    try await parakeet.loadIfNeeded(progress: progressHandler)
                } else {
                    try await whisper.loadIfNeeded(progress: progressHandler)
                }
                NSLog("[Sussurro] Model pre-load succeeded")
            } catch {
                NSLog("[Sussurro] Model pre-load failed: %@", error.localizedDescription)
            }
            bar.setLoadingTooltip(nil)
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
