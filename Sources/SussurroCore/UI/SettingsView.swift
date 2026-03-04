import SwiftUI
import KeyboardShortcuts

// MARK: – Supporting types

struct LanguageOption: Identifiable {
    let id: String  // BCP-47 code, or "auto"
    let name: String
}

// MARK: – View Model

/// Observable settings state. Changes are saved to disk and applied to the
/// Transcriber immediately so they take effect on the next dictation.
@MainActor
public final class AppSettings: ObservableObject {

    @Published public var transcriptionEngine: String
    @Published public var dictationModel: String
    @Published public var batchModel: String
    @Published public var language: String
    
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
    @Published public var devStack: String

    public let modelManager: ModelManager
    public let mlxModelManager = MLXModelManager()
    private let transcriber: Transcriber
    private var config: AppConfig

    // swiftlint:disable trailing_comma
    static let languages: [LanguageOption] = [
        LanguageOption(id: "auto", name: L10n("Auto-detectar")),
        LanguageOption(id: "pt", name: L10n("Português")),
        LanguageOption(id: "en", name: L10n("English")),
        LanguageOption(id: "es", name: L10n("Español")),
        LanguageOption(id: "fr", name: L10n("Français")),
        LanguageOption(id: "de", name: L10n("Deutsch")),
        LanguageOption(id: "it", name: L10n("Italiano")),
        LanguageOption(id: "ja", name: L10n("日本語")),
        LanguageOption(id: "zh", name: L10n("中文")),
        LanguageOption(id: "ko", name: L10n("한국어")),
        LanguageOption(id: "ru", name: L10n("Русский")),
        LanguageOption(id: "ar", name: L10n("العربية")),
    ]
    // swiftlint:enable trailing_comma

    public init(
        config: AppConfig,
        transcriber: Transcriber,
        modelManager: ModelManager
    ) {
        self.config = config
        self.transcriptionEngine = config.transcriptionEngine
        self.dictationModel = config.dictationModel
        self.batchModel = config.batchModel
        self.language = config.language
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
        self.devStack = config.devStack

        self.transcriber = transcriber
        self.modelManager = modelManager
    }

    /// Persists current values and updates the Transcriber without requiring a restart.
    public func save() {
        config.transcriptionEngine = transcriptionEngine
        config.dictationModel = dictationModel
        config.batchModel = batchModel
        config.language = language
        config.dictationTemperature = dictationTemperature
        config.batchTemperature = batchTemperature
        config.replacements = replacements
        config.replacementRules = replacementRules
        config.defaultExportPath = defaultExportPath
        config.enableDiarization = enableDiarization
        config.selectedDictationTemplate = selectedDictationTemplate
        config.llmProvider = llmProvider
        config.llmPrompt = llmPrompt
        config.openAIKey = openAIKey
        config.geminiKey = geminiKey
        config.geminiModel = geminiModel
        config.openAIModel = openAIModel
        config.mlxModel = mlxModel
        config.modeConfigs = modeConfigs
        config.customModeName = String(customModeName.prefix(30))
        config.customModePrompt = customModePrompt
        config.devStack = devStack

        // Native macOS persistence via UserDefaults
        config.save()
        
        Task { await transcriber.setModel(dictationModel) }
        Task {
            await transcriber.setConfig(
                language: language,
                temperature: dictationTemperature,
                prompt: ""
            )
        }
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

enum SettingsPanel: String, CaseIterable, Identifiable {
    case general = "Geral"
    case models = "Modelos"
    case advanced = "Avançado"
    case llm = "IA & LLM"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .models: return "cpu"
        case .advanced: return "gearshape.2"
        case .llm: return "wand.and.stars"
        }
    }
    
    var localizedName: String {
        switch self {
        case .general: return L10n("Geral")
        case .models: return L10n("Modelos")
        case .advanced: return L10n("Avançado")
        case .llm: return L10n("IA & LLM")
        }
    }
}

enum SettingsSelection: Hashable {
    case panel(SettingsPanel)
    case template(DictationTemplate)
}

// MARK: – Settings View

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var modelManager: ModelManager
    @State private var selection: SettingsSelection? = .panel(.general)
    @State var newIncorrect: String = ""
    @State var newCorrect: String = ""
    
    // Key testing state
    @State var isTestingKey = false
    @State var testKeyResult: String?
    @State var showTestKeyAlert = false
    @State var availableGeminiModels: [String] = [
        "gemini-2.0-flash", "gemini-2.5-flash", "gemini-1.5-flash"
    ]

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section {
                    ForEach(SettingsPanel.allCases) { panel in
                        Label(panel.localizedName, systemImage: panel.icon)
                            .tag(SettingsSelection.panel(panel))
                    }
                }
                
                Section(L10n("Modos")) {
                    ForEach(DictationTemplate.allCases.filter { !$0.isCreativeMode }, id: \.self) { template in
                        Label(template.localizedName, systemImage: template.icon)
                            .tag(SettingsSelection.template(template))
                    }
                }

                Section(L10n("Prompts Criativos")) {
                    ForEach(DictationTemplate.allCases.filter { $0.isCreativeMode }, id: \.self) { template in
                        Label(template.localizedName, systemImage: template.icon)
                            .tag(SettingsSelection.template(template))
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
            .listStyle(.sidebar)
        } detail: {
            if let selection {
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
                    }
                case .template(let template):
                    ModeDetailView(template: template, settings: settings)
                        .id(template)
                }
            } else {
                Text(L10n("Selecione um painel à esquerda"))
                    .foregroundColor(.secondary)
            }
        }
        .toolbar(removing: .sidebarToggle)
        .frame(minWidth: WindowSize.settingsDefaultWidth, minHeight: WindowSize.settingsDefaultHeight)
        .observeSettingsChanges(settings)
    }
}

extension View {
    func observeSettingsChanges(_ settings: AppSettings) -> some View {
        self
            .onChange(of: settings.transcriptionEngine) { settings.save() }
            .onChange(of: settings.dictationModel) { settings.save() }
            .onChange(of: settings.batchModel) { settings.save() }
            .onChange(of: settings.language) { settings.save() }
            .onChange(of: settings.dictationTemperature) { settings.save() }
            .onChange(of: settings.batchTemperature) { settings.save() }
            .onChange(of: settings.replacements) { settings.save() }
            .onChange(of: settings.replacementRules) { settings.save() }
            .observeMoreSettingsChanges(settings)
    }
    
    func observeMoreSettingsChanges(_ settings: AppSettings) -> some View {
        self
            .onChange(of: settings.enableDiarization) { settings.save() }
            .onChange(of: settings.selectedDictationTemplate) { settings.save() }
            .onChange(of: settings.llmProvider) { settings.save() }
            .onChange(of: settings.llmPrompt) { settings.save() }
            .observeCredentialsChanges(settings)
    }
    
    func observeCredentialsChanges(_ settings: AppSettings) -> some View {
        self
            .onChange(of: settings.openAIKey) { settings.save() }
            .onChange(of: settings.geminiKey) { settings.save() }
            .onChange(of: settings.geminiModel) { settings.save() }
            .onChange(of: settings.openAIModel) { settings.save() }
            .onChange(of: settings.mlxModel) { settings.save() }
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
