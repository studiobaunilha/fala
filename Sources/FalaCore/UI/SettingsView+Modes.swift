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
        let resolution = settings.mlxCatalogService.resolveSelection(repoID: model)
        return resolution.entry?.displayName ?? L10n("Modelo incompatível")
    }

    /// The provider actually used for prompt resolution (resolves "global").
    private var effectiveProvider: String {
        (provider == "global") ? settings.llmProvider : provider
    }

    private var isPromptModified: Bool {
        prompt != restoreBaselinePrompt
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

            if template.requiresLLM {
                providerSection
                promptSection
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
            .onChange(of: provider) {
                // Reload prompt for new provider before saving
                prompt = resolvedPromptForCurrentProvider()
                debouncedSave()
            }

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
                            Button(L10n("Padrão global")) {
                                model = ""
                            }

                            ForEach(settings.mlxCatalogService.sections(selectedRepoID: settings.mlxModel)) { section in
                                Section(section.title) {
                                    ForEach(section.entries) { entry in
                                        Button(entry.displayName) {
                                            model = entry.repoID
                                        }
                                    }
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
            Text(L10n("Provedor de IA"))
        } footer: {
            Text(L10n("Selecione \"Usar Padrão Global\" para herdar o provedor configurado no painel IA & LLM."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var promptSection: some View {
        Section {
            PromptEditorPanel(
                text: $prompt,
                isModified: isPromptModified,
                restoreActionTitle: L10n("Restaurar Padrão"),
                onRestore: {
                    if isPromptModified {
                        showRestoreConfirmation = true
                    }
                },
                supplementary: {
                    if isEffectiveProviderAppleIntelligence {
                        PromptEditorNote(
                            message: L10n(
                                // swiftlint:disable:next line_length
                                "Ideal para tarefas simples como limpar e formatar texto. Para prompts criativos ou complexos (Dev, Sumário), considere Gemini, OpenAI ou MLX."
                            )
                        )
                    }
                }
            )
            .onChange(of: prompt) { debouncedSave() }
        } header: {
            Text(
                String(
                    format: L10n("Prompt do Sistema — %@"),
                    localizedProviderName(for: effectiveProvider)
                )
            )
        } footer: {
            // swiftlint:disable:next line_length
            Text(L10n("Instruções enviadas ao LLM para processar a transcrição neste modo. Cada provedor pode ter seu próprio prompt otimizado."))
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
                    Text(
                        // swiftlint:disable:next line_length
                        L10n("Este modo não utiliza IA. O texto é inserido diretamente pelo motor de transcrição selecionado.")
                    )
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
        effectiveProvider == "apple"
    }

    /// The default prompt for the current effective provider + template.
    private var restoreBaselinePrompt: String {
        if template == .custom {
            return AppConfig.localizedDefault(for: .customModePrompt)
        }
        return PromptDefaults.resolved(for: effectiveProvider, template: template)
            ?? template.defaultSystemPrompt
            ?? ""
    }

    /// Resolves what prompt to display for the current provider.
    private func resolvedPromptForCurrentProvider() -> String {
        let config = settings.modeConfigs[template.rawValue]
        let ep = effectiveProvider

        // 1. Per-provider override
        if let providerPrompt = config?.providerPrompts?[ep], !providerPrompt.isEmpty {
            return providerPrompt
        }
        // 2. General prompt override
        if let modePrompt = config?.prompt {
            return modePrompt
        }
        // 3. Custom mode fallback
        if template == .custom {
            return settings.customModePrompt
        }
        // 4. PromptDefaults for this provider
        if let defaultPrompt = PromptDefaults.resolved(for: ep, template: template) {
            return defaultPrompt
        }
        // 5. Template fallback
        return template.defaultSystemPrompt ?? ""
    }

    private func loadConfig() {
        let config = settings.modeConfigs[template.rawValue]
        self.provider = config?.provider ?? "global"
        self.model = config?.model ?? ""
        self.prompt = resolvedPromptForCurrentProvider()
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

        let ep = effectiveProvider
        let isDefault = (prompt == restoreBaselinePrompt)

        // For .custom mode, save to customModePrompt
        if template == .custom {
            settings.customModePrompt = prompt
            config.prompt = nil
            // Clear any per-provider override if user restored default
            if isDefault {
                config.providerPrompts?.removeValue(forKey: ep)
                if config.providerPrompts?.isEmpty == true {
                    config.providerPrompts = nil
                }
            }
        } else if isDefault {
            // Matches the default — clear overrides
            config.prompt = nil
            config.providerPrompts?.removeValue(forKey: ep)
            if config.providerPrompts?.isEmpty == true {
                config.providerPrompts = nil
            }
        } else {
            // Save as per-provider override
            var prompts = config.providerPrompts ?? [:]
            prompts[ep] = prompt
            config.providerPrompts = prompts
            // Clear generic prompt to avoid confusion
            config.prompt = nil
        }

        settings.modeConfigs[template.rawValue] = config
        settings.save()
    }

    private func restoreDefault() {
        prompt = restoreBaselinePrompt
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
