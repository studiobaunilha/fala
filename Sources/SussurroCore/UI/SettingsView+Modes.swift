import SwiftUI

// swiftlint:disable:next type_body_length
struct ModeDetailView: View {
    let template: DictationTemplate
    @ObservedObject var settings: AppSettings

    // Local state for editing
    @State private var provider: String = "global"
    @State private var model: String = ""
    @State private var prompt: String = ""
    @State private var showRestoreConfirmation = false
    @State private var saveTask: Task<Void, Never>?

    // Available providers
    private let providers = [
        ("global", "Usar Padrão Global"),
        ("gemini", "Google Gemini"),
        ("openai", "OpenAI GPT"),
        ("apple", "Apple Intelligence"),
        ("mlx", "MLX Local")
    ]

    private var effectiveProviderName: String {
        if provider == "global" {
            let globalProvider = settings.llmProvider
            let name = providers.first { $0.0 == globalProvider }?.1 ?? globalProvider
            return name
        }
        return providers.first { $0.0 == provider }?.1 ?? provider
    }

    private var mlxModelLabel: String {
        if model.isEmpty {
            return "Padrão global"
        }
        return knownMLXModels
            .first { $0.repoID == model }?.label ?? model
    }

    private var isPromptModified: Bool {
        if template == .custom {
            return false // Custom mode prompt is always user-defined
        }
        return prompt != (template.defaultSystemPrompt ?? "")
    }

    var body: some View {
        Form {
            descriptionSection

            if template == .custom {
                customNameSection
            }

            if template.requiresLLM {
                providerSection
                promptSection
            } else {
                noLLMSection
            }
        }
        .formStyle(.grouped)
        .navigationTitle(template == .custom ? settings.customModeName : template.rawValue)
        .onAppear { loadConfig() }
        .confirmationDialog(
            "Restaurar prompt padrão?",
            isPresented: $showRestoreConfirmation,
            titleVisibility: .visible
        ) {
            Button("Restaurar Padrão", role: .destructive) {
                restoreDefault()
            }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("O prompt customizado será substituído pelo padrão deste modo. Esta ação não pode ser desfeita.")
        }
    }

    // MARK: - Sections

    private var descriptionSection: some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(template.rawValue)
                        .font(.headline)
                    Text(template.modeDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: template.icon)
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 28)
            }
            .padding(.vertical, Spacing.xs)
        }
    }

    private var providerSection: some View {
        Section {
            Picker("Provedor LLM", selection: $provider) {
                ForEach(providers, id: \.0) { key, name in
                    Text(name).tag(key)
                }
            }
            .onChange(of: provider) { debouncedSave() }

            if provider == "global" {
                LabeledContent("Provedor atual") {
                    Text(effectiveProviderName)
                        .foregroundStyle(.secondary)
                }
            }

            if provider != "global" && provider != "apple" {
                if provider == "mlx" {
                    LabeledContent("Modelo") {
                        Menu {
                            ForEach(knownMLXModels) { mlxModel in
                                Button(mlxModel.label) {
                                    model = mlxModel.repoID
                                }
                            }
                        } label: {
                            Text(mlxModelLabel)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .onChange(of: model) { debouncedSave() }
                } else {
                    TextField("Modelo", text: $model,
                              prompt: Text("Padrão do provedor"))
                        .onChange(of: model) { debouncedSave() }
                }
            }
        } header: {
            Text("Modelo")
        } footer: {
            Text("Selecione \"Usar Padrão Global\" para herdar o provedor configurado no painel IA & LLM.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var promptSection: some View {
        Section {
            TextEditor(text: $prompt)
                .frame(minHeight: 150)
                .font(.body.monospaced())
                .scrollContentBackground(.hidden)
                .padding(Spacing.xs)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(Color(nsColor: .separatorColor))
                )
                .onChange(of: prompt) { debouncedSave() }

            HStack {
                Button("Restaurar Padrão") {
                    if isPromptModified {
                        showRestoreConfirmation = true
                    }
                }
                .disabled(!isPromptModified)

                Spacer()

                if isPromptModified {
                    Label("Modificado", systemImage: "pencil.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        } header: {
            Text("Prompt do Sistema")
        } footer: {
            Text("Instruções enviadas ao LLM para processar a transcrição neste modo.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var customNameSection: some View {
        Section {
            TextField("Nome do modo", text: $settings.customModeName)
                .onChange(of: settings.customModeName) {
                    // Enforce 30 char limit
                    if settings.customModeName.count > 30 {
                        settings.customModeName = String(settings.customModeName.prefix(30))
                    }
                    debouncedSave()
                }
        } header: {
            Text("Nome Personalizado")
        } footer: {
            Text("Este nome aparece no menu da barra de status. Máximo 30 caracteres.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var noLLMSection: some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Sem pós-processamento")
                        .font(.body)
                    Text("Este modo não utiliza IA. O texto é inserido diretamente do Whisper.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "bolt.horizontal")
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, Spacing.xs)
        } header: {
            Text("Processamento")
        }
    }

    // MARK: - Logic

    private var effectiveDefaultPrompt: String {
        if template == .custom {
            return settings.customModePrompt
        }
        return template.defaultSystemPrompt ?? ""
    }

    private func loadConfig() {
        if let config = settings.modeConfigs[template.rawValue] {
            self.provider = config.provider ?? "global"
            self.model = config.model ?? ""
            self.prompt = config.prompt ?? effectiveDefaultPrompt
        } else {
            self.provider = "global"
            self.model = ""
            self.prompt = effectiveDefaultPrompt
        }
    }

    private func debouncedSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            persistConfig()
        }
    }

    private func persistConfig() {
        var config = settings.modeConfigs[template.rawValue] ?? ModeConfig()

        config.provider = (provider == "global") ? nil : provider
        config.model = model.isEmpty ? nil : model

        // For .custom mode, save the prompt to customModePrompt directly
        if template == .custom {
            settings.customModePrompt = prompt
            config.prompt = nil
        } else if prompt == template.defaultSystemPrompt {
            config.prompt = nil
        } else {
            config.prompt = prompt
        }

        settings.modeConfigs[template.rawValue] = config
        settings.save()
    }

    private func restoreDefault() {
        prompt = template == .custom
            ? "Resuma o texto transcrito em um parágrafo conciso, capturando os pontos principais."
            : (template.defaultSystemPrompt ?? "")
        persistConfig()
    }
}
