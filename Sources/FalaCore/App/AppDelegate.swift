import AppKit
import Sparkle
import Combine

private struct DictationTranscriberServices {
    let resolve: (AppConfig) -> any AudioTranscribing
    let prewarm: (AppConfig) async -> Void
}

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var updaterController: SPUStandardUpdaterController?
    private var statusBar: StatusBarController?
    private var dictationMode: DictationMode?
    private var settingsController: SettingsWindowController?
    private var transcribeController: TranscribeWindowController?
    private var feedbackController: DictationFeedbackController?
    private var onboardingController: OnboardingWindowController?
    private var appSettings: AppSettings?
    private var cancellables = Set<AnyCancellable>()

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
            parakeetTranscriber: parakeetTranscriber,
            updater: updaterController?.updater
        )
        self.appSettings = appSettings

        let settingsCtrl = SettingsWindowController(settings: appSettings)
        settingsController = settingsCtrl

        let transcribeCtrl = TranscribeWindowController(settings: appSettings)
        transcribeController = transcribeCtrl

        let onboardingViewModel = OnboardingViewModel(
            settings: appSettings,
            readiness: appSettings.readiness,
            permissionProvider: appSettings.permissionProvider
        )
        let onboardingCtrl = OnboardingWindowController(viewModel: onboardingViewModel)
        onboardingController = onboardingCtrl

        AppMainMenu.install(appDelegate: self)

        let bar = StatusBarController(
            settings: appSettings,
            onSettings: { settingsCtrl.show() },
            onTranscribe: { transcribeCtrl.show() }
        )

        let transcriberServices = DictationTranscriberServices(
            resolve: { runtimeConfig in
                if runtimeConfig.transcriptionEngine == "parakeet" {
                    return parakeetTranscriber as any AudioTranscribing
                }
                return whisperTranscriber as any AudioTranscribing
            },
            prewarm: { runtimeConfig in
                await Self.prewarmDictationTranscriber(
                    config: runtimeConfig,
                    whisperTranscriber: whisperTranscriber,
                    parakeetTranscriber: parakeetTranscriber
                )
            }
        )
        let feedbackCtrl = DictationFeedbackController()
        feedbackController = feedbackCtrl

        let dictation = makeDictationMode(
            statusBar: bar,
            feedback: feedbackCtrl,
            configProvider: { appSettings.snapshotConfig() },
            transcriberServices: transcriberServices,
            readiness: appSettings.readiness
        )

        statusBar = bar
        dictationMode = dictation
        observeLanguageChanges()
        observeRuntimeEvents(settings: appSettings)

        dictation.setup()
        appSettings.warmupCoordinator.scheduleSelectedWarmup()
        syncDownloadUI(for: bar, settings: appSettings)
        onboardingCtrl.showIfNeeded()
    }

    private func makeDictationMode(
        statusBar: StatusBarController,
        feedback: DictationFeedbackController,
        configProvider: @escaping () -> AppConfig,
        transcriberServices: DictationTranscriberServices,
        readiness: RuntimeReadinessEvaluator
    ) -> DictationMode {
        let initialConfig = configProvider()
        return DictationMode(
            recorder: AudioEngine(),
            transcriber: transcriberServices.resolve(initialConfig),
            inserter: TextInserter(),
            statusBar: statusBar,
            feedback: feedback,
            configProvider: configProvider,
            transcriberResolver: transcriberServices.resolve,
            transcriberPrewarmer: transcriberServices.prewarm,
            readiness: readiness
        )
    }

    @objc
    public func showSettingsWindow() {
        settingsController?.show()
    }

    private func observeLanguageChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLanguageChanged),
            name: AppLocalization.languageChangedNotification,
            object: nil
        )
    }

    private func observeRuntimeEvents(settings: AppSettings) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWhisperModelDownloadCompleted),
            name: .whisperModelDownloadCompleted,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMLXModelDownloadCompleted),
            name: .mlxDownloadCompleted,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )

        settings.readiness.refresh()
    }

    @objc private func handleWhisperModelDownloadCompleted() {
        appSettings?.warmupCoordinator.scheduleSelectedWarmup()
        appSettings?.readiness.refresh()
        onboardingController?.reloadContent()
    }

    @objc private func handleMLXModelDownloadCompleted(_ notification: Notification) {
        if let repoID = notification.userInfo?["repoID"] as? String {
            appSettings?.mlxDownloadWarmupGate.recordCompletion(repoID: repoID)
        }
        // Avoid loading large MLX weights into memory immediately when a download finishes.
        // A follow-up warmup can happen on later app activity or explicit use.
        appSettings?.warmupCoordinator.scheduleSelectedWarmup(includeLLM: false)
        appSettings?.readiness.refresh()
        onboardingController?.reloadContent()
    }

    @objc private func handleAppDidBecomeActive() {
        statusBar?.reloadLocalizedContent()
        settingsController?.reloadLocalizedContent()
        transcribeController?.reloadLocalizedContent()
        onboardingController?.reloadContent()
        onboardingController?.showIfNeeded()
        appSettings?.warmupCoordinator.scheduleSelectedWarmup()
        appSettings?.readiness.refresh()
    }

    private func syncDownloadUI(for bar: StatusBarController, settings: AppSettings) {
        Publishers.CombineLatest(
            settings.modelManager.$downloads,
            settings.mlxModelManager.$downloads
        )
        .sink { [weak bar, weak settings] whisperDownloads, mlxDownloads in
            guard let bar, let settings else { return }

            if let activeDownload = settings.activeModelDownload(
                whisperDownloads: whisperDownloads,
                mlxDownloads: mlxDownloads
            ) {
                bar.setDownloadProgress(
                    activeDownload.fraction,
                    modelName: activeDownload.modelName
                )
            } else {
                bar.clearDownloadProgress()
            }
        }
        .store(in: &cancellables)
    }

    @objc private func handleLanguageChanged() {
        reloadLocalizedUI()
    }

    private func reloadLocalizedUI() {
        AppMainMenu.install(appDelegate: self)
        statusBar?.reloadLocalizedContent()
        settingsController?.reloadLocalizedContent()
        transcribeController?.reloadLocalizedContent()
        onboardingController?.reloadContent()
    }
}

private extension AppDelegate {
    static func prewarmDictationTranscriber(
        config: AppConfig,
        whisperTranscriber: Transcriber,
        parakeetTranscriber: ParakeetTranscriber
    ) async {
        do {
            if config.transcriptionEngine == "parakeet" {
                try await parakeetTranscriber.loadIfNeeded()
                return
            }

            await whisperTranscriber.setModel(config.dictationModel)
            await whisperTranscriber.setConfig(
                language: config.transcriptionLanguage,
                temperature: config.dictationTemperature,
                prompt: ""
            )
            try await whisperTranscriber.loadIfNeeded()
        } catch {
            NSLog("[Fala] Dictation prewarm failed: %@", error.localizedDescription)
        }
    }
}
