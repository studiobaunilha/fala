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
    @Published public var dictationModel: String
    @Published public var batchModel: String
    @Published public var transcriptionLanguage: String

    @Published public var dictationTemperature: Float
    @Published public var batchTemperature: Float
    @Published public var replacements: [String: String]
    @Published public var replacementRules: [ReplacementRule]
    @Published public var defaultExportPath: String
    @Published public var enableDiarization: Bool

    @Published public var selectedDictationTemplate: DictationTemplate
    @Published public var llmProvider: String
    @Published public var llmPrompt: String
    @Published public var openAIKey: String
    @Published public var geminiKey: String
    @Published public var geminiModel: String
    @Published public var openAIModel: String
    @Published public var mlxModel: String
    @Published public var modeConfigs: [String: ModeConfig]
    @Published public var customModeName: String
    @Published public var customModePrompt: String
    @Published public var globalSystemPrompt: String

    public let modelManager: ModelManager
    public let mlxModelManager: MLXModelManager
    public let mlxCatalogService: MLXCatalogService
    public lazy var warmupCoordinator: WarmupCoordinator = WarmupCoordinator(
        whisperTranscriber: transcriber,
        parakeetTranscriber: parakeetTranscriber,
        mlxCatalogService: mlxCatalogService,
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
    var config: AppConfig
    var openSettingsSelection: ((SettingsSelection) -> Void)?

    public init(
        config: AppConfig,
        transcriber: Transcriber,
        modelManager: ModelManager,
        parakeetTranscriber: ParakeetTranscriber = ParakeetTranscriber(),
        mlxModelManager: MLXModelManager = MLXModelManager(),
        restartCoordinator: AppRestartCoordinator = AppRestartCoordinator(),
        permissionProvider: SystemPermissionProviding = SystemPermissionProvider(),
        updater: SPUUpdater? = nil
    ) {
        self.config = config
        self.appLanguage = config.appLanguage
        self.transcriptionEngine = config.transcriptionEngine
        self.dictationModel = config.dictationModel
        self.batchModel = config.batchModel
        self.transcriptionLanguage = config.transcriptionLanguage
        self.dictationTemperature = config.dictationTemperature
        self.batchTemperature = config.batchTemperature
        self.replacements = config.replacements
        self.replacementRules = config.replacementRules
        self.defaultExportPath = config.defaultExportPath
        self.enableDiarization = config.enableDiarization
        self.selectedDictationTemplate = config.selectedDictationTemplate
        self.llmProvider = config.llmProvider
        self.llmPrompt = config.llmPrompt
        self.openAIKey = config.openAIKey
        self.geminiKey = config.geminiKey
        self.geminiModel = config.geminiModel
        self.openAIModel = config.openAIModel
        self.mlxModel = config.mlxModel
        self.modeConfigs = config.modeConfigs
        self.customModeName = config.customModeName
        self.customModePrompt = config.customModePrompt
        self.globalSystemPrompt = config.globalSystemPrompt

        self.transcriber = transcriber
        self.parakeetTranscriber = parakeetTranscriber
        self.modelManager = modelManager
        self.mlxModelManager = mlxModelManager
        self.mlxCatalogService = MLXCatalogService(manager: mlxModelManager)
        self.restartCoordinator = restartCoordinator
        self.permissionProvider = permissionProvider
        self.updater = updater
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
            LanguageOption(id: "es", name: L10n("Español"))
        ]
    }

    var supportsExplicitEngineLanguageSelection: Bool {
        transcriptionEngine == "whisper"
    }

    var availableLanguagesForEngine: [LanguageOption] {
        supportsExplicitEngineLanguageSelection ? Self.whisperLanguages() : []
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
        snapshot.dictationModel = dictationModel
        snapshot.batchModel = batchModel
        snapshot.transcriptionLanguage = transcriptionLanguage
        snapshot.dictationTemperature = dictationTemperature
        snapshot.batchTemperature = batchTemperature
        snapshot.replacements = replacements
        snapshot.replacementRules = replacementRules
        snapshot.defaultExportPath = defaultExportPath
        snapshot.enableDiarization = enableDiarization
        snapshot.selectedDictationTemplate = selectedDictationTemplate
        snapshot.llmProvider = llmProvider
        snapshot.llmPrompt = llmPrompt
        snapshot.openAIKey = openAIKey
        snapshot.geminiKey = geminiKey
        snapshot.geminiModel = geminiModel
        snapshot.openAIModel = openAIModel
        snapshot.mlxModel = mlxModel
        snapshot.modeConfigs = modeConfigs
        snapshot.customModeName = String(customModeName.prefix(30))
        snapshot.customModePrompt = customModePrompt
        snapshot.globalSystemPrompt = globalSystemPrompt
        return snapshot
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
}
