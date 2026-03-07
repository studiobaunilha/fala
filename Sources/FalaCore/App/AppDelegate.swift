import AppKit
import Sparkle
import Combine

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

        let transcriberResolver: (AppConfig) -> any AudioTranscribing = { runtimeConfig in
            runtimeConfig.transcriptionEngine == "parakeet"
                ? parakeetTranscriber
                : whisperTranscriber
        }
        let feedbackCtrl = DictationFeedbackController()
        feedbackController = feedbackCtrl

        let dictation = makeDictationMode(
            statusBar: bar,
            feedback: feedbackCtrl,
            configProvider: { appSettings.snapshotConfig() },
            transcriberResolver: transcriberResolver,
            readiness: appSettings.readiness
        )

        statusBar = bar
        dictationMode = dictation
        observeLanguageChanges()
        observeRuntimeEvents(settings: appSettings)

        dictation.setup()
        appSettings.warmupCoordinator.scheduleSelectedWarmup()
        syncWarmupUI(for: bar, coordinator: appSettings.warmupCoordinator)
        syncDownloadUI(for: bar, settings: appSettings)
        onboardingCtrl.showIfNeeded()
    }

    private func makeDictationMode(
        statusBar: StatusBarController,
        feedback: DictationFeedbackController,
        configProvider: @escaping () -> AppConfig,
        transcriberResolver: @escaping (AppConfig) -> any AudioTranscribing,
        readiness: RuntimeReadinessEvaluator
    ) -> DictationMode {
        let initialConfig = configProvider()
        return DictationMode(
            recorder: AudioEngine(),
            transcriber: transcriberResolver(initialConfig),
            inserter: TextInserter(),
            statusBar: statusBar,
            feedback: feedback,
            configProvider: configProvider,
            transcriberResolver: transcriberResolver,
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
            selector: #selector(handleModelDownloadCompleted),
            name: .whisperModelDownloadCompleted,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleModelDownloadCompleted),
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

    @objc private func handleModelDownloadCompleted() {
        appSettings?.warmupCoordinator.scheduleSelectedWarmup()
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

    private func syncWarmupUI(for bar: StatusBarController, coordinator: WarmupCoordinator) {
        coordinator.objectWillChange.sink { [weak bar, weak coordinator] _ in
            guard let bar, let coordinator else { return }

            if coordinator.isPreparingSelectedResources {
                bar.setState(.loading)
                if case .warming(let label) = coordinator.transcriptionStatus {
                    bar.setLoadingTooltip(String(format: L10n("Carregando modelo %@…"), label))
                    return
                }
                if case .warming(let label) = coordinator.llmStatus {
                    bar.setLoadingTooltip(String(format: L10n("Preparando %@…"), label))
                    return
                }
            }

            bar.setLoadingTooltip(nil)
            bar.setState(.idle)
        }.store(in: &cancellables)
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
