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

    private var availableProviders: [(String, String)] {
        var list: [(String, String)] = [("global", L10n("Usar Padrão Global"))]
        list += [("apple", localizedProviderName(for: "apple")), ("mlx", localizedProviderName(for: "mlx"))]
        if !settings.geminiKey.isEmpty { list.append(("gemini", localizedProviderName(for: "gemini"))) }
        if !settings.openAIKey.isEmpty { list.append(("openai", localizedProviderName(for: "openai"))) }
        return list
    }

    private var effectiveProviderName: String {
        let key = provider == "global" ? settings.llmProvider : provider
        return localizedProviderName(for: key)
    }

    private var mlxModelLabel: String {
        if model.isEmpty {
            return L10n("Padrão global")
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

            if template == .translate && settings.transcriptionEngine != "whisper" {
                Section {
                    NoticeCard(
                        title: L10n("Motor incompatível"),
                        // swiftlint:disable:next line_length
                        message: L10n("A tradução para inglês é um recurso exclusivo do Whisper. O motor atual (Parakeet) não suporta tradução."),
                        tone: .warning
                    ) {
                        Button(L10n("Trocar para Whisper")) {
                            settings.requestTranscriptionEngineChange(
                                "whisper",
                                title: L10n("Reinício necessário"),
                                // swiftlint:disable:next line_length
                                message: L10n("A tradução para inglês requer o motor Whisper. O Fala vai trocar o motor e reiniciar agora.")
                            )
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(FalaColors.warning)
                    }
                }
            }

            if template == .custom {
                customNameSection
            }

            if template == .custom && isEffectiveProviderAppleIntelligence {
                Section {
                    NoticeCard(
                        title: L10n("Provedor incompatível"),
                        // swiftlint:disable:next line_length
                        message: L10n("O modo personalizado requer prompts avançados, incompatíveis com o Apple Intelligence, que aceita apenas instruções simples. Selecione outro provedor abaixo."),
                        tone: .warning
                    )
                }
            }

            if template.requiresLLM {
                providerSection
                if !isEffectiveProviderAppleIntelligence {
                    promptSection
                } else {
                    appleIntelligencePromptNote
                }
            } else {
                noLLMSection
            }
        }
        .formStyle(.grouped)
        .navigationTitle(template == .custom ? settings.customModeName : template.localizedName)
        .onAppear { loadConfig() }
        .confirmationDialog(
            L10n("Restaurar prompt padrão?"),
            isPresented: $showRestoreConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n("Restaurar Padrão"), role: .destructive) {
                restoreDefault()
            }
            Button(L10n("Cancelar"), role: .cancel) { }
        } message: {
            Text(L10n("O prompt customizado será substituído pelo padrão deste modo. Esta ação não pode ser desfeita."))
        }
    }

    // MARK: - Sections

    private var descriptionSection: some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(template.localizedName)
                        .font(.headline)
                    Text(template.modeDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: template.icon)
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: LayoutMetric.leadingNoticeIconWidth)
            }
            .padding(.vertical, Spacing.xs)
        }
    }

    private var providerSection: some View {
        Section {
            Picker(L10n("Provedor LLM"), selection: $provider) {
                ForEach(availableProviders, id: \.0) { key, name in
                    Text(name).tag(key)
                }
            }
            .onChange(of: provider) { debouncedSave() }

            if provider == "global" {
                LabeledContent(L10n("Provedor atual")) {
                    Text(effectiveProviderName)
                        .foregroundStyle(.secondary)
                }
            }

            if provider != "global" && provider != "apple" {
                if provider == "mlx" {
                    LabeledContent(L10n("Modelo")) {
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
                    TextField(L10n("Modelo"), text: $model,
                              prompt: Text(L10n("Padrão do provedor")))
                        .onChange(of: model) { debouncedSave() }
                }
            }
        } header: {
            Text(L10n("Modelo"))
        } footer: {
            Text(L10n("Selecione \"Usar Padrão Global\" para herdar o provedor configurado no painel IA & LLM."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var promptSection: some View {
        Section {
            EditorSurface(minHeight: LayoutMetric.promptEditorMinHeight) {
                TextEditor(text: $prompt)
                    .font(.body.monospaced())
                    .scrollContentBackground(.hidden)
                    .onChange(of: prompt) { debouncedSave() }
            }

            HStack {
                Button(L10n("Restaurar Padrão")) {
                    if isPromptModified {
                        showRestoreConfirmation = true
                    }
                }
                .disabled(!isPromptModified)

                Spacer()

                if isPromptModified {
                    Label(L10n("Modificado"), systemImage: "pencil.circle.fill")
                        .font(.caption)
                        .foregroundStyle(FalaColors.warning)
                }
            }
        } header: {
            Text(L10n("Prompt do Sistema"))
        } footer: {
            Text(L10n("Instruções enviadas ao LLM para processar a transcrição neste modo."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var customNameSection: some View {
        Section {
            TextField(L10n("Nome do modo"), text: $settings.customModeName)
                .onChange(of: settings.customModeName) {
                    // Enforce 30 char limit
                    if settings.customModeName.count > 30 {
                        settings.customModeName = String(settings.customModeName.prefix(30))
                    }
                    debouncedSave()
                }
        } header: {
            Text(L10n("Nome Personalizado"))
        } footer: {
            Text(L10n("Este nome aparece no menu da barra de status. Máximo 30 caracteres."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var noLLMSection: some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(L10n("Sem pós-processamento"))
                        .font(.body)
                    Text(L10n("Este modo não utiliza IA. O texto é inserido diretamente do Whisper."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "bolt.horizontal")
                    .foregroundStyle(.secondary)
                    .frame(width: LayoutMetric.leadingNoticeIconWidth)
            }
            .padding(.vertical, Spacing.xs)
        } header: {
            Text(L10n("Processamento"))
        }
    }

    // MARK: - Logic

    /// Whether the effective provider (after resolving "global") is Apple Intelligence.
    private var isEffectiveProviderAppleIntelligence: Bool {
        let effectiveProvider = (provider == "global") ? settings.llmProvider : provider
        return effectiveProvider == "apple"
    }

    private var appleIntelligencePromptNote: some View {
        Section {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                EditorSurface(backgroundOpacity: 0.5) {
                    Text(prompt)
                        .font(.body.monospaced())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Label {
                    // swiftlint:disable:next line_length
                    Text(L10n("Prompt somente-leitura. O Apple Intelligence usa prompts simplificados otimizados para o modelo compacto (~3B). Para editar prompts, use outro provedor."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(FalaColors.info)
                        .font(.caption)
                }
            }
        } header: {
            Text(L10n("Prompt do Sistema (Somente Leitura)"))
        }
    }

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
            ? AppConfig.localizedDefault(for: .customModePrompt)
            : (template.defaultSystemPrompt ?? "")
        persistConfig()
    }

    private func localizedProviderName(for key: String) -> String {
        switch key {
        case "global":
            return L10n("Usar Padrão Global")
        case "gemini":
            return L10n("Google Gemini (Cloud)")
        case "openai":
            return L10n("OpenAI (Cloud)")
        case "apple":
            return L10n("Apple Intelligence (Local)")
        case "mlx":
            return L10n("MLX Local")
        default:
            return key
        }
    }
}
