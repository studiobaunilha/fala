import SwiftUI
import KeyboardShortcuts

// MARK: - Painéis Nativos (Extension)

extension SettingsView {
    
    var generalView: some View {
        Form {
            systemShortcutSection
            appLanguageSection
            aiBehaviorSection
            fileExportSection
            replacementRulesSection
        }
        .formStyle(.grouped)
        .navigationTitle(L10n("Transcrição de Arquivos"))
    }
    
    func addReplacement() {
        let variant = newIncorrect.trimmingCharacters(in: .whitespacesAndNewlines)
        let correct = newCorrect.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !variant.isEmpty, !correct.isEmpty else { return }
        guard settings.addReplacementRule(variant: variant, replacement: correct) else {
            return
        }
        newIncorrect = ""
        newCorrect = ""
    }

    private var systemShortcutSection: some View {
        Section {
            KeyboardShortcuts.Recorder(L10n("Atalho de Ditado"), name: .startDictation)
        } header: {
            Text(L10n("Atalhos do Sistema"))
        } footer: {
            // swiftlint:disable:next line_length
            Text(L10n("Pressione o atalho global para iniciar o ditado de qualquer lugar. Use um modificador (⌘, ⌥, ⌃, ⇧) combinado com outra tecla, ou uma tecla F1–F20. Teclas como Tab não podem ser usadas sozinhas em atalhos globais do macOS."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var appLanguageSection: some View {
        Section {
            Picker(L10n("Idioma da Interface"), selection: $settings.appLanguage) {
                ForEach(AppSettings.appLanguageOptions()) { lang in
                    Text(lang.name).tag(lang.id)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text(L10n("Idioma do Aplicativo"))
        } footer: {
            Text(
                // swiftlint:disable:next line_length
                L10n("Automático segue o idioma do macOS. Hoje o Fala possui interface em Português, English, Español e Français.")
            )
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var fileExportSection: some View {
        Section(L10n("Armazenamento")) {
            HStack {
                TextField(L10n("Salvar Transcrições"), text: $settings.defaultExportPath)
                    .disabled(true)
                Button(L10n("Alterar...")) { settings.selectExportPath() }
            }
        }
    }

    private var aiBehaviorSection: some View {
        Section {
            Toggle(
                L10n("Colar ditado diretamente"),
                isOn: $settings.plainDictationPasteDirectly
            )

            Toggle(
                L10n("Colar resultados de IA diretamente"),
                isOn: $settings.aiResultPasteDirectly
            )
        } header: {
            Text(L10n("Comportamento de Inserção"))
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text(
                    L10n("Quando ativado, o texto do ditado é inserido imediatamente no app em foco.")
                    + " "
                    + L10n("Desativado, o ditado final é copiado para a área de transferência sem colar.")
                )

                Text(
                    L10n("Quando ativado, o resultado do comando de IA é colado diretamente.")
                    + " "
                    + L10n("Desativado, exibe o resultado para revisão antes de colar.")
                )
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var replacementRulesSection: some View {
        Section {
            HStack(spacing: Spacing.sm) {
                TextField(L10n("Variante"), text: $newIncorrect)
                    .textFieldStyle(.roundedBorder)
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                TextField(L10n("Correto"), text: $newCorrect)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addReplacement() }

                Button {
                    addReplacement()
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.plain)
                .font(.title2)
                .disabled(newIncorrect.isEmpty || newCorrect.isEmpty)
            }

            ForEach($settings.replacementRules) { $rule in
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack {
                        Text(rule.replacement)
                            .fontWeight(.medium)
                        Spacer()
                        Button(role: .destructive) {
                            withAnimation {
                                _ = settings.removeReplacementRule(id: rule.id)
                            }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                    HStack(spacing: Spacing.xs) {
                        ForEach(rule.variants, id: \.self) { variant in
                            HStack(spacing: Spacing.xxs) {
                                Text(variant)
                                    .font(.caption)
                                    .strikethrough()
                                    .foregroundStyle(.secondary)
                                Button {
                                    withAnimation {
                                        _ = settings.removeReplacementVariant(
                                            variant,
                                            fromRuleID: rule.id
                                        )
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(nsColor: .quaternaryLabelColor).opacity(0.3))
                            .clipShape(Capsule())
                        }
                    }
                }
                .padding(.vertical, Spacing.xxs)
            }
        } header: {
            Text(L10n("Substituição de Texto (Pós-processamento)"))
        } footer: {
            Text(
                L10n(
                    "Cada regra pode ter várias variantes. Se o correto já existir, a variante é adicionada à regra."
                )
            )
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    func readinessIssueCard(_ issue: ReadinessIssue) -> some View {
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

    func performReadinessAction(_ issue: ReadinessIssue) {
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
