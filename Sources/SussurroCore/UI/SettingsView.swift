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

    @Published public var dictationModel: String
    @Published public var batchModel: String
    @Published public var language: String
    
    @Published public var dictationTemperature: Float
    @Published public var batchTemperature: Float
    @Published public var customDictionary: String
    @Published public var defaultExportPath: String
    @Published public var enableDiarization: Bool
    
    @Published public var enableLLMPostProcessing: Bool
    @Published public var llmPrompt: String
    @Published public var openAIKey: String

    public let modelManager: ModelManager
    private let transcriber: Transcriber

    // swiftlint:disable trailing_comma
    static let languages: [LanguageOption] = [
        LanguageOption(id: "auto", name: "Auto-detectar"),
        LanguageOption(id: "pt", name: "Português"),
        LanguageOption(id: "en", name: "English"),
        LanguageOption(id: "es", name: "Español"),
        LanguageOption(id: "fr", name: "Français"),
        LanguageOption(id: "de", name: "Deutsch"),
        LanguageOption(id: "it", name: "Italiano"),
        LanguageOption(id: "ja", name: "日本語"),
        LanguageOption(id: "zh", name: "中文"),
        LanguageOption(id: "ko", name: "한국어"),
        LanguageOption(id: "ru", name: "Русский"),
        LanguageOption(id: "ar", name: "العربية"),
    ]
    // swiftlint:enable trailing_comma

    public init(
        config: AppConfig,
        transcriber: Transcriber,
        modelManager: ModelManager
    ) {
        self.dictationModel = config.dictationModel
        self.batchModel = config.batchModel
        self.language = config.language
        self.dictationTemperature = config.dictationTemperature
        self.batchTemperature = config.batchTemperature
        self.customDictionary = config.customDictionary
        self.defaultExportPath = config.defaultExportPath
        self.enableDiarization = config.enableDiarization
        self.enableLLMPostProcessing = config.enableLLMPostProcessing
        self.llmPrompt = config.llmPrompt
        self.openAIKey = config.openAIKey
        
        self.transcriber = transcriber
        self.modelManager = modelManager
    }

    /// Persists current values and updates the Transcriber without requiring a restart.
    public func save() {
        var config = AppConfig.load()
        config.dictationModel = dictationModel
        config.batchModel = batchModel
        config.language = language
        config.dictationTemperature = dictationTemperature
        config.batchTemperature = batchTemperature
        config.customDictionary = customDictionary
        config.defaultExportPath = defaultExportPath
        config.enableDiarization = enableDiarization
        config.enableLLMPostProcessing = enableLLMPostProcessing
        config.llmPrompt = llmPrompt
        config.openAIKey = openAIKey
        config.save()
        
        Task { await transcriber.setModel(dictationModel) }
        Task {
            await transcriber.setConfig(
                language: language,
                temperature: dictationTemperature,
                prompt: customDictionary
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
        case .general: return "gear"
        case .models: return "cpu"
        case .advanced: return "slider.horizontal.3"
        case .llm: return "wand.and.stars"
        }
    }
}

// MARK: – Settings View

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var modelManager: ModelManager
    @State private var selection: SettingsPanel? = .general

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(SettingsPanel.allCases) { panel in
                    Label(panel.rawValue, systemImage: panel.icon)
                        .tag(panel)
                }
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 250)
            .listStyle(.sidebar)
        } detail: {
            switch selection {
            case .general:
                generalView
            case .models:
                modelsView
            case .advanced:
                advancedView
            case .llm:
                llmView
            case .none:
                Text("Selecione um painel à esquerda")
                    .foregroundColor(.secondary)
            }
        }
        .frame(minWidth: WindowSize.settingsWidth, minHeight: WindowSize.settingsHeight)
        .onChange(of: settings.dictationModel) { settings.save() }
        .onChange(of: settings.batchModel) { settings.save() }
        .onChange(of: settings.language) { settings.save() }
        .onChange(of: settings.dictationTemperature) { settings.save() }
        .onChange(of: settings.batchTemperature) { settings.save() }
        .onChange(of: settings.customDictionary) { settings.save() }
        .onChange(of: settings.enableDiarization) { settings.save() }
        .onChange(of: settings.enableLLMPostProcessing) { settings.save() }
        .onChange(of: settings.llmPrompt) { settings.save() }
        .onChange(of: settings.openAIKey) { settings.save() }
    }
    
    // MARK: - Painéis Nativos
    
    private var generalView: some View {
        Form {
            Section {
                KeyboardShortcuts.Recorder("Atalho de Ditado", name: .startDictation)
            } header: {
                Text("Atalhos do Sistema")
            } footer: {
                Text("Pressione o atalho global para iniciar o ditado de qualquer lugar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("Idioma Padrão") {
                Picker("Idioma", selection: $settings.language) {
                    ForEach(AppSettings.languages) { lang in
                        Text(lang.name).tag(lang.id)
                    }
                }
                .pickerStyle(.menu)
            }
            
            Section("Armazenamento") {
                HStack {
                    TextField("Salvar Transcrições", text: $settings.defaultExportPath)
                        .disabled(true)
                    Button("Alterar...") { settings.selectExportPath() }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Ajustes Gerais")
    }
    
    private var modelsView: some View {
        Form {
            Section {
                downloadedModelPicker("Modelo de Ditado", selection: $settings.dictationModel)
                downloadedModelPicker("Modelo Batch / Arquivo", selection: $settings.batchModel)
            } header: {
                Text("Modelos Ativos")
            } footer: {
                Text("Recomenda-se um modelo menor e rápido para ditado, e um maior para arquivos.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Downloads Disponíveis") {
                ForEach(knownModels) { model in
                    ModelRow(
                        model: model,
                        manager: modelManager,
                        isDictation: settings.dictationModel == model.id,
                        isBatch: settings.batchModel == model.id
                    )
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Gerenciador de Modelos")
    }
    
    private var advancedView: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Temperatura Ditado (\(settings.dictationTemperature, specifier: "%.1f"))")
                    Slider(value: $settings.dictationTemperature, in: 0.0...1.0, step: 0.1)
                }
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Temperatura Batch (\(settings.batchTemperature, specifier: "%.1f"))")
                    Slider(value: $settings.batchTemperature, in: 0.0...1.0, step: 0.1)
                }
            } header: {
                Text("Acurácia vs. Velocidade")
            } footer: {
                Text("Zero significa alta acurácia (Greedy Decoding).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section {
                TextField("Palavras customizadas...", text: $settings.customDictionary, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.roundedBorder)
            } header: {
                Text("Dicionário (Initial Prompt)")
            } footer: {
                Text("Termos específicos, siglas ou gírias para priorizar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("Diarization (Identificação de Vozes)") {
                Toggle("Reconhecer múltiplos locutores", isOn: $settings.enableDiarization)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Avançado")
    }
    
    private var llmView: some View {
        Form {
            Section {
                Toggle("Habilitar Correção com LLM", isOn: $settings.enableLLMPostProcessing)
            } footer: {
                Text("Usa inteligência artificial (OpenAI) para corrigir pontuação e falhas.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if settings.enableLLMPostProcessing {
                Section("Credenciais") {
                    SecureField("OpenAI API Key", text: $settings.openAIKey)
                        .textFieldStyle(.roundedBorder)
                }
                
                Section("Instrução (Prompt)") {
                    TextField("Como o LLM deve se comportar?", text: $settings.llmPrompt, axis: .vertical)
                        .lineLimit(4...8)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Pós-processamento")
    }

    @ViewBuilder
    private func downloadedModelPicker(
        _ label: String,
        selection: Binding<String>
    ) -> some View {
        let downloaded = knownModels.filter { modelManager.isDownloaded($0.id) }
        Picker(label, selection: selection) {
            ForEach(downloaded) { model in
                Text("\(model.label)  \(model.estimatedSize)").tag(model.id)
            }
        }
        .pickerStyle(.menu)
    }
}

// MARK: – Model Row

private struct ModelRow: View {
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
                .help(isActive ? "Não pode apagar modelo ativo" : "Apagar modelo")
            } else {
                Button {
                    manager.download(model.id)
                } label: {
                    Image(systemName: "arrow.down.circle")
                }
                .buttonStyle(.borderless)
                .help("Baixar modelo")
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    private var sizeLabel: String {
        manager.diskSize(for: model.id) ?? model.estimatedSize
    }
}
