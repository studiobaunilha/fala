import AppKit
import Sparkle
import Combine

private struct DictationTranscriberServices {
    let resolve: (AppConfig) -> any AudioTranscribing
    let prewarm: @Sendable (AppConfig) async -> Void
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
    private var releaseNotesController: ReleaseNotesWindowController?
    private var insertionReviewController: InsertionReviewController?
    private var appSettings: AppSettings?
    private var cancellables = Set<AnyCancellable>()

    // swiftlint:disable:next function_body_length
    public func applicationDidFinishLaunching(_ notification: Notification) {
        CrashReporter.shared.start()

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
        let disableNeuralEngine = HardwareInfo.isKnownToFreezeWhisperANE && !config.forceWhisperNeuralEngine
        let whisperTranscriber = Transcriber(
            modelName: config.activeWhisperModel,
            language: config.transcriptionLanguage,
            temperature: config.dictationTemperature,
            prompt: "",
            disableNeuralEngine: disableNeuralEngine
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
        let insertionReviewCtrl = InsertionReviewController(
            learnCorrection: { original, corrected in
                if appSettings.addReplacementRule(
                    variant: original,
                    replacement: corrected
                ) {
                    appSettings.save()
                    print(
                        "[Fala] Saved learned correction: '\(original)' -> '\(corrected)'"
                    )
                }
            }
        )
        insertionReviewController = insertionReviewCtrl

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
        LicenseManager.shared.reconcileEntitlementOnAppLaunch()
        appSettings.warmupCoordinator.scheduleSelectedWarmup()
        syncDownloadUI(for: bar, settings: appSettings)
        let wasUpgrade = VersionChangeDetector.handleVersionChangeIfNeeded()
        onboardingCtrl.showIfNeeded()

        let releaseNotesCtrl = ReleaseNotesWindowController()
        releaseNotesController = releaseNotesCtrl
        if wasUpgrade {
            releaseNotesCtrl.showIfNeededForCurrentVersion()
        }
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
            readiness: readiness,
            selectionCapture: SelectionCapture(),
            selectionCommandController: SelectionCommandController(),
            insertionReviewPresenter: insertionReviewController
        )
    }

    @objc
    public func showSettingsWindow() {
        settingsController?.show()
    }
}

private extension AppDelegate {
    func observeLanguageChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLanguageChanged),
            name: AppLocalization.languageChangedNotification,
            object: nil
        )
    }

    func observeRuntimeEvents(settings: AppSettings) {
        NotificationCenter.default.publisher(for: .whisperModelDownloadCompleted)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                self?.handleWhisperModelDownloadCompleted(notification)
            }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: .mlxDownloadCompleted)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                self?.handleMLXModelDownloadCompleted(notification)
            }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleAppDidBecomeActive()
            }
            .store(in: &cancellables)

        settings.$fnDoublePressActivationEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                self?.dictationMode?.setFnDoublePressActivationEnabled(enabled)
            }
            .store(in: &cancellables)

        settings.readiness.refresh()
    }

    func handleWhisperModelDownloadCompleted(_ notification: Notification) {
        guard let settings = appSettings else { return }

        if let modelID = notification.userInfo?["modelId"] as? String {
            settings.selectWhisperModelAfterDownload(modelID)
        } else {
            settings.warmupCoordinator.scheduleSelectedWarmup()
            settings.readiness.refresh()
        }
        onboardingController?.reloadContent()
    }

    func handleMLXModelDownloadCompleted(_ notification: Notification) {
        guard let settings = appSettings else { return }

        if let repoID = notification.userInfo?["repoID"] as? String {
            settings.mlxDownloadWarmupGate.recordCompletion(repoID: repoID)
            settings.selectMLXModelAfterDownload(repoID)
        } else {
            // Avoid loading large MLX weights into memory immediately when a download finishes.
            // A follow-up warmup can happen on later app activity or explicit use.
            settings.warmupCoordinator.scheduleSelectedWarmup(includeLLM: false)
            settings.readiness.refresh()
        }
        onboardingController?.reloadContent()
    }

    func handleAppDidBecomeActive() {
        statusBar?.reloadLocalizedContent()
        settingsController?.reloadLocalizedContent()
        transcribeController?.reloadLocalizedContent()
        onboardingController?.reloadContent()
        onboardingController?.showIfNeeded()
        appSettings?.warmupCoordinator.scheduleSelectedWarmup()
        appSettings?.readiness.refresh()
    }

    func syncDownloadUI(for bar: StatusBarController, settings: AppSettings) {
        Publishers.CombineLatest(
            settings.modelManager.$downloads,
            settings.mlxModelManager.$downloads
        )
        .receive(on: RunLoop.main)
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

    @objc func handleLanguageChanged() {
        reloadLocalizedUI()
    }

    func reloadLocalizedUI() {
        AppMainMenu.install(appDelegate: self)
        statusBar?.reloadLocalizedContent()
        settingsController?.reloadLocalizedContent()
        transcribeController?.reloadLocalizedContent()
        onboardingController?.reloadContent()
    }

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

            await whisperTranscriber.setModel(config.activeWhisperModel)
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
