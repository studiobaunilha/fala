import SwiftUI
import KeyboardShortcuts

// MARK: - Painéis Nativos (Extension)

extension SettingsView {
    
    var generalView: some View {
        Form {
            Section {
                KeyboardShortcuts.Recorder(L10n("Atalho de Ditado"), name: .startDictation)
            } header: {
                Text(L10n("Atalhos do Sistema"))
            } footer: {
                Text(L10n("Pressione o atalho global para iniciar o ditado de qualquer lugar."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
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
                    L10n("Automático segue o idioma do macOS. Hoje o Fala possui interface em Português, English e Español.")
                )
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section(L10n("Armazenamento")) {
                HStack {
                    TextField(L10n("Salvar Transcrições"), text: $settings.defaultExportPath)
                        .disabled(true)
                    Button(L10n("Alterar...")) { settings.selectExportPath() }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(L10n("Ajustes Gerais"))
    }
    
    var advancedView: some View {
        Form {
            if settings.transcriptionEngine == "whisper" {
                Section {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("\(L10n("Temperatura Ditado")) (\(settings.dictationTemperature, specifier: "%.1f"))")
                        Slider(value: $settings.dictationTemperature, in: 0.0...1.0, step: 0.1)
                    }
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("\(L10n("Temperatura Batch")) (\(settings.batchTemperature, specifier: "%.1f"))")
                        Slider(value: $settings.batchTemperature, in: 0.0...1.0, step: 0.1)
                    }
                } header: {
                    Text(L10n("Acurácia vs. Velocidade"))
                } footer: {
                    Text(L10n("Zero significa alta acurácia (Greedy Decoding). Aplicável apenas ao motor Whisper."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Section {
                Toggle(L10n("Reconhecer múltiplos locutores"), isOn: $settings.enableDiarization)
                    .disabled(settings.llmProvider == "apple")
            } header: {
                Text(L10n("Diarization (Identificação de Vozes)"))
            } footer: {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    // swiftlint:disable:next line_length
                    Text(L10n("Apenas para transcrição de arquivos. Usa pós-processamento com IA para separar locutores — não é detecção acústica. A qualidade depende do modelo de IA selecionado."))
                        .foregroundStyle(.secondary)
                    
                    if settings.llmProvider == "apple" {
                        // swiftlint:disable:next line_length
                        Label(L10n("Indisponível com Apple Intelligence (requer modelo mais avançado)"), systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(FalaColors.warning)
                    }
                }
                .font(.caption)
            }
            
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
                                    settings.replacementRules.removeAll { $0.id == rule.id }
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
                                            rule.variants.removeAll { $0 == variant }
                                            if rule.variants.isEmpty {
                                                settings.replacementRules.removeAll { $0.id == rule.id }
                                            }
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
                // swiftlint:disable:next line_length
                Text(L10n("Cada regra pode ter várias variantes. Se o correto já existir, a variante é adicionada à regra."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(L10n("Avançado"))
    }
    
    func addReplacement() {
        let variant = newIncorrect.trimmingCharacters(in: .whitespacesAndNewlines)
        let correct = newCorrect.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !variant.isEmpty, !correct.isEmpty else { return }

        // If a rule for this replacement word already exists, add the variant to it
        if let idx = settings.replacementRules.firstIndex(where: {
            $0.replacement.caseInsensitiveCompare(correct) == .orderedSame
        }) {
            if !settings.replacementRules[idx].variants.contains(where: {
                $0.caseInsensitiveCompare(variant) == .orderedSame
            }) {
                settings.replacementRules[idx].variants.append(variant)
            }
        } else {
            settings.replacementRules.append(
                ReplacementRule(variants: [variant], replacement: correct)
            )
        }
        newIncorrect = ""
        newCorrect = ""
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
        case .validateLicense:
            Task {
                await LicenseManager.shared.refreshEntitlement()
                settings.readiness.refresh()
            }
        }
    }
}
