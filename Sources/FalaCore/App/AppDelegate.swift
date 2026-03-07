import AppKit
import AVFoundation
import Sparkle

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var updaterController: SPUStandardUpdaterController?
    private var statusBar: StatusBarController?
    private var dictationMode: DictationMode?
    private var settingsController: SettingsWindowController?
    private var transcribeController: TranscribeWindowController?
    private var feedbackController: DictationFeedbackController?

    // swiftlint:disable:next function_body_length
    public func applicationDidFinishLaunching(_ notification: Notification) {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        
        // Run as a background app — no Dock icon.
        NSApp.setActivationPolicy(.accessory)
        AppLifecyclePolicy.apply()

        let config = AppConfig.load()
        AppLocalization.apply(languageCode: config.appLanguage)
        let whisperTranscriber = Transcriber(
            modelName: config.dictationModel,
            language: config.transcriptionLanguage,
            temperature: config.dictationTemperature,
            prompt: ""
        )
        let parakeetTranscriber = ParakeetTranscriber()
        let modelManager = ModelManager()
        modelManager.scanLocal()
        let appSettings = AppSettings(
            config: config,
            transcriber: whisperTranscriber,
            modelManager: modelManager,
            updater: updaterController?.updater
        )

        let settingsCtrl = SettingsWindowController(settings: appSettings)
        settingsController = settingsCtrl

        let transcribeCtrl = TranscribeWindowController(settings: appSettings)
        transcribeController = transcribeCtrl

        AppMainMenu.install(appDelegate: self)

        let bar = StatusBarController(
            settings: appSettings,
            onSettings: { settingsCtrl.show() },
            onTranscribe: { transcribeCtrl.show() }
        )

        let transcriberResolver: (AppConfig) -> any AudioTranscribing = { runtimeConfig in
            runtimeConfig.transcriptionEngine == "parakeet"
                ? parakeetTranscriber
                : whisperTranscriber
        }
        let activeTranscriber = transcriberResolver(config)

        let feedbackCtrl = DictationFeedbackController()
        feedbackController = feedbackCtrl

        let dictation = makeDictationMode(
            statusBar: bar,
            feedback: feedbackCtrl,
            configProvider: { AppConfig.load() },
            transcriberResolver: transcriberResolver
        )

        statusBar = bar
        dictationMode = dictation
        observeLanguageChanges()

        dictation.setup()
        requestMicrophoneAccess()
        preloadModel(config: config, transcriber: activeTranscriber, whisper: whisperTranscriber, bar: bar)
    }

    private func makeDictationMode(
        statusBar: StatusBarController,
        feedback: DictationFeedbackController,
        configProvider: @escaping () -> AppConfig,
        transcriberResolver: @escaping (AppConfig) -> any AudioTranscribing
    ) -> DictationMode {
        let initialConfig = configProvider()
        return DictationMode(
            recorder: AudioEngine(),
            transcriber: transcriberResolver(initialConfig),
            inserter: TextInserter(),
            statusBar: statusBar,
            feedback: feedback,
            configProvider: configProvider,
            transcriberResolver: transcriberResolver
        )
    }

    @objc
    public func showSettingsWindow() {
        settingsController?.show()
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
                    ? L10n("Parakeet V3") : config.dictationModel
                    
                let progressHandler: @Sendable (Double) -> Void = { [weak bar] fraction in
                    Task { @MainActor in
                        bar?.setDownloadProgress(fraction, modelName: name)
                    }
                }
                
                bar.setLoadingTooltip(String(format: L10n("Carregando modelo %@…"), name))
                NSLog("[Fala] Starting model pre-load: %@", name)
                if let parakeet = transcriber as? ParakeetTranscriber {
                    try await parakeet.loadIfNeeded(progress: progressHandler)
                } else {
                    try await whisper.loadIfNeeded(progress: progressHandler)
                }
                NSLog("[Fala] Model pre-load succeeded")
            } catch {
                NSLog("[Fala] Model pre-load failed: %@", error.localizedDescription)
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
                    print("[Fala] Microphone access denied.")
                }
            }
        case .denied, .restricted:
            print("[Fala] Microphone access denied. Enable in System Settings → Privacy → Microphone.")
        @unknown default:
            break
        }
    }

    private func observeLanguageChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLanguageChanged),
            name: AppLocalization.languageChangedNotification,
            object: nil
        )
    }

    @objc private func handleLanguageChanged() {
        reloadLocalizedUI()
    }

    private func reloadLocalizedUI() {
        AppMainMenu.install(appDelegate: self)
        statusBar?.reloadLocalizedContent()
        settingsController?.reloadLocalizedContent()
        transcribeController?.reloadLocalizedContent()
    }

}
