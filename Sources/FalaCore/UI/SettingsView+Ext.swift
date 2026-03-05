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
            
            Section(L10n("Idioma Padrão")) {
                Picker(L10n("Idioma"), selection: $settings.language) {
                    ForEach(settings.availableLanguagesForEngine) { lang in
                        Text(lang.name).tag(lang.id)
                    }
                }
                .pickerStyle(.menu)
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
    
    var modelsView: some View {
        Form {
            Section {
                Picker(L10n("Motor de Transcrição"), selection: $settings.transcriptionEngine) {
                    Text(L10n("Whisper (WhisperKit)")).tag("whisper")
                    Text(L10n("Parakeet V3 (FluidAudio)")).tag("parakeet")
                }
            } header: {
                Text(L10n("Motor de Transcrição"))
            } footer: {
                if settings.transcriptionEngine == "parakeet" {
                    // swiftlint:disable:next line_length
                    Text(L10n("Parakeet V3 usa CoreML/ANE para transcrição ultra-rápida. Suporta 25 idiomas europeus. O modelo é baixado automaticamente no primeiro uso. Requer reiniciar o app após alterar."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(L10n("Whisper usa modelos OpenAI via WhisperKit. Requer reiniciar o app após alterar."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if settings.transcriptionEngine == "whisper" {
                Section {
                    downloadedModelPicker(L10n("Modelo de Ditado"), selection: $settings.dictationModel)
                    downloadedModelPicker(L10n("Modelo Batch / Arquivo"), selection: $settings.batchModel)
                } header: {
                    Text(L10n("Modelos Whisper Ativos"))
                } footer: {
                    Text(L10n("Recomenda-se um modelo menor e rápido para ditado, e um maior para arquivos."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if settings.transcriptionEngine == "whisper" {
                Section(L10n("Modelos Whisper (Offline)")) {
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
        }
        .formStyle(.grouped)
        .navigationTitle(L10n("Gerenciador de Modelos"))
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
            } header: {
                Text(L10n("Diarization (Identificação de Vozes)"))
            } footer: {
                Text(L10n("Apenas para transcrição de arquivos. Tenta separar o texto por locutores diferentes."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                                HStack(spacing: 2) {
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
    func downloadedModelPicker(
        _ label: String,
        selection: Binding<String>
    ) -> some View {
        let downloaded = knownModels.filter { modelManager.isDownloaded($0.id) }
        Picker(label, selection: selection) {
            Text(L10n("Nenhum")).tag("none")
            if !downloaded.isEmpty {
                Divider()
            }
            ForEach(downloaded) { model in
                Text("\(model.label)  \(model.estimatedSize)").tag(model.id)
            }
        }
        .pickerStyle(.menu)
    }
}
