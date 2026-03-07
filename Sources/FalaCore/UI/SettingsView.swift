import SwiftUI
import KeyboardShortcuts
import Sparkle
import WhisperKit

// MARK: – Supporting types

public struct LanguageOption: Identifiable {
    public let id: String  // BCP-47 code, or "auto"
    public let name: String
}

@MainActor
final class SettingsNavigationState: ObservableObject {
    @Published var selection: SettingsSelection? = .panel(.general)
}

// MARK: – View Model

/// Observable settings state. Changes are saved to disk and applied to the
/// Transcriber immediately so they take effect on the next dictation.
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
    public let mlxModelManager = MLXModelManager()
    public let updater: SPUUpdater?
    let transcriber: Transcriber
    var config: AppConfig

    public static func appLanguageOptions() -> [LanguageOption] {
        return [
            LanguageOption(id: "auto", name: L10n("Automático (Sistema)")),
            LanguageOption(id: "pt-BR", name: L10n("Português")),
            LanguageOption(id: "en", name: L10n("English")),
            LanguageOption(id: "es", name: L10n("Español"))
        ]
    }

    public var supportsExplicitEngineLanguageSelection: Bool {
        transcriptionEngine == "whisper"
    }

    public var availableLanguagesForEngine: [LanguageOption] {
        supportsExplicitEngineLanguageSelection ? Self.whisperLanguages() : []
    }

    public func transcriptionLanguageName(for code: String) -> String {
        Self.whisperLanguages().first(where: { $0.id == code })?.name ?? code
    }

    public func appLanguageName(for code: String) -> String {
        let resolvedCode = AppLocalization.resolveLanguageCode(code)
        return Self.appLanguageOptions().first(where: { $0.id == resolvedCode })?.name ?? resolvedCode
    }

    private static let whisperLanguageEnglishNames: [String: String] = {
        var names: [String: String] = [:]
        for (englishName, code) in Constants.languages where names[code] == nil {
            names[code] = englishName
        }
        return names
    }()

    public static func whisperLanguages(
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

    public static func transcriptionLanguageDisplayName(
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

    public init(
        config: AppConfig,
        transcriber: Transcriber,
        modelManager: ModelManager,
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
        self.modelManager = modelManager
        self.updater = updater
    }

    public func selectExportPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            defaultExportPath = url.path
            save()
        }
    }
}

// MARK: – View Components

// MARK: – Settings View

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var modelManager: ModelManager
    @ObservedObject var navigationState: SettingsNavigationState
    @ObservedObject var licenseManager = LicenseManager.shared
    @ObservedObject private var localizationObserver = AppLocalizationObserver.shared
    @State var newIncorrect: String = ""
    @State var newCorrect: String = ""
    @State var activationCode: String = ""
    @FocusState var focusedField: SettingsFocusedField?
    
    // Key testing state
    @State var isTestingKey = false
    @State var testKeyResult: String?
    @State var showTestKeyAlert = false
    @State var availableGeminiModels: [String] = [
        "gemini-2.0-flash", "gemini-2.5-flash", "gemini-1.5-flash"
    ]

    var body: some View {
        NavigationSplitView {
            List(selection: $navigationState.selection) {
                Section {
                    ForEach(SettingsPanel.allCases) { panel in
                        Label(panel.localizedName, systemImage: panel.icon)
                            .tag(SettingsSelection.panel(panel))
                    }
                }
                
                Section(L10n("Modos")) {
                    ForEach(DictationTemplate.allCases, id: \.self) { template in
                        HStack {
                            Label(template.localizedName, systemImage: template.icon)
                            if template == .translate && settings.transcriptionEngine != "whisper" {
                                Spacer()
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                    .help(L10n("Tradução requer o motor Whisper"))
                            }
                            if template == .custom && settings.llmProvider == "apple" {
                                Spacer()
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                    .help(L10n("Modo personalizado requer provedor diferente do Apple Intelligence"))
                            }
                        }
                        .tag(SettingsSelection.template(template))
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
            .listStyle(.sidebar)
        } detail: {
            if let selection = navigationState.selection {
                switch selection {
                case .panel(let panel):
                    switch panel {
                    case .general:
                        generalView
                    case .models:
                        modelsView
                    case .advanced:
                        advancedView
                    case .llm:
                        llmView
                    case .license:
                        licenseView
                    case .updates:
                        updatesView
                    case .about:
                        aboutView
                    }
                case .template(let template):
                    ModeDetailView(template: template, settings: settings)
                        .id(template)
                }
            } else {
                Text(L10n("Selecione um painel à esquerda"))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar(removing: .sidebarToggle)
        .id(localizationObserver.revision)
        .environment(\.locale, AppLocalization.currentLocale())
        .frame(minWidth: WindowSize.settingsDefaultWidth, minHeight: WindowSize.settingsDefaultHeight)
        .observeSettingsChanges(settings)
    }
}

// MARK: – Model Row

struct ModelRow: View {
    let model: ModelInfo
    @ObservedObject var manager: ModelManager
    let isDictation: Bool
    let isBatch: Bool

    private var isDownloaded: Bool { manager.isDownloaded(model.id) }
    private var progress: Double? { manager.downloads[model.id] }
    private var isActive: Bool { isDictation || isBatch }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(spacing: Spacing.sm) {
                    Text(model.label)
                        .font(.body)
                    if isDownloaded {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.green)
                            .font(.caption)
                    }
                }
                HStack(spacing: Spacing.md) {
                    Text(sizeLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if isDictation {
                        RoleBadge.dictation
                    }
                    if isBatch {
                        RoleBadge.batch
                    }
                }
            }

            Spacer()

            if let progress {
                ProgressView(value: progress)
                    .frame(width: 80)
                    .controlSize(.small)
                Text("\(Int(progress * 100))%")
                    .font(.caption).monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 32, alignment: .trailing)
            } else if isDownloaded {
                Button(role: .destructive) {
                    try? manager.delete(model.id)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .disabled(isActive)
                .help(isActive ? L10n("Não pode apagar modelo ativo") : L10n("Apagar modelo"))
            } else {
                Button {
                    manager.download(model.id)
                } label: {
                    Image(systemName: "arrow.down.circle")
                }
                .buttonStyle(.borderless)
                .help(L10n("Baixar modelo"))
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    private var sizeLabel: String {
        manager.diskSize(for: model.id) ?? model.estimatedSize
    }
}
