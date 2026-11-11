import AppKit
import Combine
import Sparkle
import WhisperKit

public struct LanguageOption: Identifiable {
    public let id: String
    public let name: String
}

@MainActor
final class SettingsNavigationState: ObservableObject {
    @Published var selection: SettingsSelection? = .panel(.general)
}

@MainActor
public final class AppSettings: ObservableObject {
    @Published public var appLanguage: String
    @Published public var transcriptionEngine: String
    @Published public var parakeetModel: ParakeetModel
    @Published public var dictationModel: String
    @Published public var batchModel: String
    @Published public var transcriptionLanguage: String

    @Published public var dictationTemperature: Float
    @Published public var batchTemperature: Float
    @Published public var replacements: [String: String]
    @Published public var replacementRules: [ReplacementRule]
    @Published var parakeetVocabularyTerms: [ParakeetVocabularyTerm] = []
    @Published var vocabularyContextsEnabled = false
    @Published var vocabularyContexts: [VocabularyContext] = []
    @Published var selectedVocabularyContextID: UUID?
    @Published public var defaultExportPath: String
    @Published public var forceWhisperNeuralEngine: Bool

    @Published public var selectedDictationTemplate: DictationTemplate
    @Published public var llmProvider: String
    @Published public var llmPrompt: String
    @Published public var openAIKey: String
    @Published public var geminiKey: String
    @Published public var geminiModel: String
    @Published public var openAIModel: String
    @Published public var mlxModel: String
    @Published public var mlxCatalogMigrationNotice: MLXCatalogMigrationNotice?
    @Published public var modeConfigs: [String: ModeConfig]
    @Published public var selectionCommandConfig: SelectionCommandConfig
    @Published public var customModeName: String
    @Published public var customModePrompt: String
    @Published public var globalSystemPrompt: String
    @Published public var plainDictationPasteDirectly: Bool
    @Published public var aiResultPasteDirectly: Bool

    public let modelManager: ModelManager
    public let mlxModelManager: MLXModelManager
    public let mlxCatalogService: MLXCatalogService
    public let mlxDownloadWarmupGate: MLXDownloadWarmupGate
    public lazy var warmupCoordinator: WarmupCoordinator = WarmupCoordinator(
        whisperTranscriber: transcriber,
        parakeetTranscriber: parakeetTranscriber,
        mlxCatalogService: mlxCatalogService,
        mlxDownloadWarmupGate: mlxDownloadWarmupGate,
        configProvider: { [weak self] in self?.snapshotConfig() ?? AppConfig.load() }
    )
    public lazy var readiness: RuntimeReadinessEvaluator = RuntimeReadinessEvaluator(
        settings: self,
        modelManager: modelManager,
        mlxCatalogService: mlxCatalogService,
        permissionProvider: permissionProvider,
        warmupCoordinator: warmupCoordinator
    )
    public let restartCoordinator: AppRestartCoordinator
    public let permissionProvider: SystemPermissionProviding
    public let updater: SPUUpdater?

    let transcriber: Transcriber
    let parakeetTranscriber: ParakeetTranscriber
    var persistVocabularyConfiguration: (AppConfig) -> Void = { $0.save() }
    var config: AppConfig
    var openSettingsSelection: ((SettingsSelection) -> Void)?

    public init(
        config: AppConfig,
        transcriber: Transcriber,
        modelManager: ModelManager,
        parakeetTranscriber: ParakeetTranscriber? = nil,
        mlxModelManager: MLXModelManager = MLXModelManager(),
        mlxDownloadWarmupGate: MLXDownloadWarmupGate = MLXDownloadWarmupGate(),
        restartCoordinator: AppRestartCoordinator = AppRestartCoordinator(),
        permissionProvider: SystemPermissionProviding = SystemPermissionProvider(),
        updater: SPUUpdater? = nil
    ) {
        let catalogService = MLXCatalogService(manager: mlxModelManager)
        let normalization = catalogService.normalize(config: config)
        var normalizedConfig = normalization.config
        let originalWhisperSelection = (normalizedConfig.dictationModel, normalizedConfig.batchModel)
        normalizedConfig.normalizeWhisperModelSelection()
        let didNormalizeWhisperSelection =
            originalWhisperSelection.0 != normalizedConfig.dictationModel
            || originalWhisperSelection.1 != normalizedConfig.batchModel

        self.config = normalizedConfig
        self.appLanguage = normalizedConfig.appLanguage
        self.transcriptionEngine = normalizedConfig.transcriptionEngine
        self.parakeetModel = normalizedConfig.parakeetModel
        self.dictationModel = normalizedConfig.dictationModel
        self.batchModel = normalizedConfig.batchModel
        self.transcriptionLanguage = normalizedConfig.transcriptionLanguage
        self.dictationTemperature = normalizedConfig.dictationTemperature
        self.batchTemperature = normalizedConfig.batchTemperature
        self.replacements = normalizedConfig.replacements
        self.replacementRules = normalizedConfig.replacementRules
        self.defaultExportPath = normalizedConfig.defaultExportPath
        self.forceWhisperNeuralEngine = normalizedConfig.forceWhisperNeuralEngine
        self.selectedDictationTemplate = normalizedConfig.selectedDictationTemplate
        self.llmProvider = normalizedConfig.llmProvider
        self.llmPrompt = normalizedConfig.llmPrompt
        self.openAIKey = normalizedConfig.openAIKey
        self.geminiKey = normalizedConfig.geminiKey
        self.geminiModel = normalizedConfig.geminiModel
        self.openAIModel = normalizedConfig.openAIModel
        self.mlxModel = normalizedConfig.mlxModel
        self.mlxCatalogMigrationNotice = normalization.migrationNotice
        self.modeConfigs = normalizedConfig.modeConfigs
        self.selectionCommandConfig = normalizedConfig.selectionCommandConfig
        self.customModeName = normalizedConfig.customModeName
        self.customModePrompt = normalizedConfig.customModePrompt
        self.globalSystemPrompt = normalizedConfig.globalSystemPrompt
        self.plainDictationPasteDirectly = normalizedConfig.plainDictationPasteDirectly
        self.aiResultPasteDirectly = normalizedConfig.aiResultPasteDirectly

        self.transcriber = transcriber
        self.parakeetTranscriber = parakeetTranscriber ?? ParakeetTranscriber(model: normalizedConfig.parakeetModel)
        self.modelManager = modelManager
        self.mlxModelManager = mlxModelManager
        self.mlxCatalogService = catalogService
        self.mlxDownloadWarmupGate = mlxDownloadWarmupGate
        self.restartCoordinator = restartCoordinator
        self.permissionProvider = permissionProvider
        self.updater = updater
        loadVocabularyContexts(from: normalizedConfig)

        if normalization.didChange || didNormalizeWhisperSelection {
            normalizedConfig.save()
        }
    }
}

private extension AppSettings {
    static let whisperLanguageEnglishNames: [String: String] = {
        var names: [String: String] = [:]
        for (englishName, code) in Constants.languages where names[code] == nil {
            names[code] = englishName
        }
        return names
    }()
}

public extension AppSettings {
    static func appLanguageOptions() -> [LanguageOption] {
        [
            LanguageOption(id: "auto", name: L10n("Automático (Sistema)")),
            LanguageOption(id: "pt-BR", name: L10n("Português")),
            LanguageOption(id: "en", name: L10n("English")),
            LanguageOption(id: "es", name: L10n("Español")),
            LanguageOption(id: "fr", name: L10n("Français"))
        ]
    }

    var supportsExplicitEngineLanguageSelection: Bool {
        transcriptionEngine == "whisper"
    }

    var availableLanguagesForEngine: [LanguageOption] {
        supportsExplicitEngineLanguageSelection ? Self.whisperLanguages() : []
    }

    var visibleDictationTemplates: [DictationTemplate] {
        let currentLang = transcriptionLanguage
        return DictationTemplate.allCases.filter { template in
            if template == .askAI {
                return false
            }
            if template == .translate {
                // Hide translate if the source language is already explicitly English
                return currentLang != "en" && currentLang != "en-US"
            }
            return true
        }
    }

    func transcriptionLanguageName(for code: String) -> String {
        Self.whisperLanguages().first(where: { $0.id == code })?.name ?? code
    }

    func appLanguageName(for code: String) -> String {
        let resolvedCode = AppLocalization.resolveLanguageCode(code)
        return Self.appLanguageOptions().first(where: { $0.id == resolvedCode })?.name ?? resolvedCode
    }

    static func whisperLanguages(
        displayLocale: Locale = AppLocalization.currentLocale()
    ) -> [LanguageOption] {
        let options = Constants.languageCodes
            .sorted()
            .map { code in
                LanguageOption(
                    id: code,
                    name: transcriptionLanguageDisplayName(for: code, displayLocale: displayLocale)
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        return [LanguageOption(id: "auto", name: L10n("Auto-detectar"))] + options
    }

    static func transcriptionLanguageDisplayName(
        for code: String,
        displayLocale: Locale = AppLocalization.currentLocale()
    ) -> String {
        if code == "auto" {
            return L10n("Auto-detectar")
        }

        let normalizedCode = code.replacingOccurrences(of: "-", with: "_")
        if let localized = displayLocale.localizedString(forIdentifier: normalizedCode), !localized.isEmpty {
            return localized.capitalized(with: displayLocale)
        }

        if let englishName = whisperLanguageEnglishNames[code] {
            return englishName.capitalized
        }

        return code
    }

    func selectExportPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            defaultExportPath = url.path
            save()
        }
    }

    func snapshotConfig() -> AppConfig {
        var snapshot = config
        snapshot.appLanguage = appLanguage
        snapshot.transcriptionEngine = transcriptionEngine
        snapshot.parakeetModel = parakeetModel
        snapshot.dictationModel = dictationModel
        snapshot.batchModel = batchModel
        snapshot.transcriptionLanguage = transcriptionLanguage
        snapshot.dictationTemperature = dictationTemperature
        snapshot.batchTemperature = batchTemperature
        snapshot.replacements = replacements
        snapshot.replacementRules = replacementRules
        snapshot.parakeetVocabularyTerms = parakeetVocabularyTerms
        snapshot.vocabularyContextsEnabled = vocabularyContextsEnabled
        snapshot.vocabularyContexts = vocabularyContexts
        snapshot.selectedVocabularyContextID = selectedVocabularyContextID
        snapshot.defaultExportPath = defaultExportPath
        snapshot.forceWhisperNeuralEngine = forceWhisperNeuralEngine
        snapshot.selectedDictationTemplate = selectedDictationTemplate
        snapshot.llmProvider = llmProvider
        snapshot.llmPrompt = llmPrompt
        snapshot.openAIKey = openAIKey
        snapshot.geminiKey = geminiKey
        snapshot.geminiModel = geminiModel
        snapshot.openAIModel = openAIModel
        snapshot.mlxModel = mlxModel
        snapshot.modeConfigs = modeConfigs
        snapshot.selectionCommandConfig = selectionCommandConfig
        snapshot.customModeName = String(customModeName.prefix(30))
        snapshot.customModePrompt = customModePrompt
        snapshot.globalSystemPrompt = globalSystemPrompt
        snapshot.plainDictationPasteDirectly = plainDictationPasteDirectly
        snapshot.aiResultPasteDirectly = aiResultPasteDirectly
        return snapshot
    }

    var selectionPasteDirectly: Bool {
        get { aiResultPasteDirectly }
        set { aiResultPasteDirectly = newValue }
    }

    var isAppleProviderUsable: Bool {
        #if canImport(FoundationModels)
        if #available(macOS 26, *) {
            return true
        }
        #endif
        return false
    }

    func openSettings(_ selection: SettingsSelection) {
        openSettingsSelection?(selection)
    }

    func requestTranscriptionEngineChange(
        _ newValue: String,
        title: String? = nil,
        message: String? = nil,
        additionalChanges: (() -> Void)? = nil
    ) {
        guard newValue != transcriptionEngine else {
            return
        }

        let currentValue = transcriptionEngine
        let resolvedTitle = title ?? L10n("Reinício necessário")
        let resolvedMessage = message
            ?? String(
                format: L10n("Trocar o motor de transcrição de %@ para %@ exige reiniciar o app."),
                currentValue,
                newValue
            )

        let didRestart = restartCoordinator.confirmAndRestart(
            title: resolvedTitle,
            message: resolvedMessage
        ) { [weak self] in
            guard let self else { return }
            self.transcriptionEngine = newValue
            additionalChanges?()
            self.save()
        }

        if !didRestart {
            objectWillChange.send()
        }
    }

    var activeWhisperModel: String {
        get {
            AppConfig.resolveActiveWhisperModel(
                dictationModel: dictationModel,
                batchModel: batchModel
            )
        }
        set {
            guard dictationModel != newValue || batchModel != newValue else {
                return
            }
            dictationModel = newValue
            batchModel = newValue
        }
    }

    func selectWhisperModelAfterDownload(_ modelID: String) {
        guard knownModels.contains(where: { $0.id == modelID }) else {
            return
        }
        activeWhisperModel = modelID
        save()
    }

    func selectMLXModelAfterDownload(_ repoID: String) {
        guard mlxCatalogService.resolveSelection(repoID: repoID).status != .unsupported else {
            return
        }
        mlxModel = repoID
        save(includeLLMWarmup: false)
    }

    var isCompatibilityModeActive: Bool {
        HardwareInfo.isKnownToFreezeWhisperANE && !forceWhisperNeuralEngine
    }
}
