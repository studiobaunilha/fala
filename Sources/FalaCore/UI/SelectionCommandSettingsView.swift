import SwiftUI

struct SelectionCommandSettingsView: View {
    @ObservedObject var settings: AppSettings

    @State private var prompt: String = ""
    @State private var showRestoreConfirmation = false
    @State private var saveTask: Task<Void, Never>?

    var body: some View {
        Group {
            descriptionSection
            readinessSection
            providerSection
            promptSection
        }
        .onAppear { loadConfig() }
        .onChange(of: settings.llmProvider, initial: false) { _, _ in
            loadConfig()
        }
        .confirmationDialog(
            L10n("Restaurar prompt padrão?"),
            isPresented: $showRestoreConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n("Restaurar Padrão"), role: .destructive) {
                restoreDefault()
            }
            Button(L10n("Cancelar"), role: .cancel) {}
        } message: {
            Text(
                L10n(
                    // swiftlint:disable:next line_length
                    "O prompt customizado será substituído pelo padrão desta ferramenta. Esta ação não pode ser desfeita."
                )
            )
        }
    }

    private var descriptionSection: some View {
        Section(L10n("Seleção + IA")) {
            Text(
                L10n(
                    "Usado quando você seleciona um texto e dita uma instrução ou pergunta sobre ele."
                )
            )
            .font(.body)
        }
    }

    private var providerSection: some View {
        Section {
            LabeledContent(L10n("Provedor LLM")) {
                Text(localizedProviderName(for: effectiveProvider))
                    .foregroundStyle(.secondary)
            }

            LabeledContent(L10n("Modelo")) {
                Text(globalModelLabel)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text(L10n("Provedor de IA"))
        } footer: {
            Text(
                L10n(
                    "O provedor e o modelo desta ferramenta seguem a configuração global de IA & LLM."
                )
            )
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
                                "Ideal para ajustes simples sobre a seleção. Para instruções longas ou complexas, considere Gemini, OpenAI ou MLX."
                            )
                        )
                    }
                }
            )
            .onChange(of: prompt, initial: false) { _, _ in
                debouncedSave()
            }
        } header: {
            Text(
                String(
                    format: L10n("Prompt do Sistema — %@"),
                    localizedProviderName(for: effectiveProvider)
                )
            )
        } footer: {
            Text(
                L10n(
                    // swiftlint:disable:next line_length
                    "Instruções enviadas ao LLM para agir sobre o texto selecionado. Cada provedor pode ter seu próprio prompt otimizado."
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

private extension SelectionCommandSettingsView {
    var blockingIssue: ReadinessIssue? {
        settings.readiness.issuesForSelectionCommand().first(where: \.blocking)
    }

    var effectiveProvider: String {
        settings.llmProvider
    }

    var effectiveModel: String {
        switch effectiveProvider {
        case "gemini":
            return settings.geminiModel
        case "openai":
            return settings.openAIModel
        case "mlx":
            return settings.mlxModel
        case "apple":
            return "apple"
        default:
            return ""
        }
    }

    var globalModelLabel: String {
        switch effectiveProvider {
        case "gemini":
            return settings.geminiModel
        case "openai":
            return settings.openAIModel
        case "mlx":
            let resolution = settings.mlxCatalogService.resolveSelection(
                repoID: settings.mlxModel
            )
            return resolution.entry?.displayName ?? L10n("Modelo incompatível")
        case "apple":
            return L10n("Apple Intelligence")
        default:
            return effectiveProvider
        }
    }

    var isPromptModified: Bool {
        prompt != restoreBaselinePrompt
    }

    var isEffectiveProviderAppleIntelligence: Bool {
        effectiveProvider == "apple"
    }

    var restoreBaselinePrompt: String {
        PromptDefaults.selectionCommandPrompt(for: effectiveProvider)
    }
}

private extension SelectionCommandSettingsView {
    @ViewBuilder
    var readinessSection: some View {
        if let issue = blockingIssue {
            Section {
                NoticeCard(
                    title: issue.title,
                    message: issue.message,
                    tone: .warning
                ) {
                    if let actionTitle = issue.actionTitle {
                        Button(actionTitle) {
                            performReadinessAction(issue)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
    }

    private func resolvedPromptForCurrentProvider() -> String {
        let config = settings.selectionCommandConfig
        let provider = effectiveProvider

        if let prompt = config.providerPrompts?[provider], !prompt.isEmpty {
            return prompt
        }

        if let prompt = config.prompt, !prompt.isEmpty {
            return prompt
        }

        return restoreBaselinePrompt
    }

    private func loadConfig() {
        prompt = resolvedPromptForCurrentProvider()
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
        var config = settings.selectionCommandConfig
        let provider = effectiveProvider

        if prompt == restoreBaselinePrompt {
            config.providerPrompts?.removeValue(forKey: provider)
            if config.providerPrompts?.isEmpty == true {
                config.providerPrompts = nil
            }
            config.prompt = nil
        } else {
            var prompts = config.providerPrompts ?? [:]
            prompts[provider] = prompt
            config.providerPrompts = prompts
            config.prompt = nil
        }

        settings.selectionCommandConfig = config
        settings.save()
    }

    private func restoreDefault() {
        prompt = restoreBaselinePrompt
        persistConfig()
    }

    private func localizedProviderName(for key: String) -> String {
        switch key {
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

    private func performReadinessAction(_ issue: ReadinessIssue) {
        switch issue.action {
        case .none:
            return
        case .openSettings(let selection):
            settings.openSettings(selection)
        case .openMicrophoneSettings:
            if settings.permissionProvider.microphonePermissionState() == .notDetermined {
                Task {
                    _ = await settings.permissionProvider.requestMicrophoneAccess()
                    settings.readiness.refresh()
                }
            } else {
                settings.permissionProvider.openMicrophoneSettings()
            }
        case .openAccessibilitySettings:
            settings.permissionProvider.openAccessibilitySettings()
        }
    }
}
