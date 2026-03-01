import SwiftUI
import KeyboardShortcuts

// MARK: - Painéis Nativos (Extension)

extension SettingsView {
    
    var generalView: some View {
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
    
    var modelsView: some View {
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
    
    var advancedView: some View {
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
                HStack {
                    TextField("Adicionar palavra...", text: $newWord)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addWord() }
                    Button("Adicionar") { addWord() }
                        .disabled(newWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                
                if !settings.customDictionary.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(settings.customDictionary, id: \.self) { word in
                                HStack(spacing: 4) {
                                    Text(word)
                                    Button {
                                        removeWord(word)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(16)
                            }
                        }
                    }
                    .frame(height: 32)
                }
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
            
            Section {
                HStack(spacing: Spacing.sm) {
                    TextField("Variante (ex: flitu)", text: $newIncorrect)
                        .textFieldStyle(.roundedBorder)
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)
                    TextField("Correto (ex: Fleetu)", text: $newCorrect)
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
                Text("Substituição de Texto (Pós-processamento)")
            } footer: {
                Text("Cada regra pode ter várias variantes. Se o correto já existir, a variante é adicionada à regra.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Avançado")
    }
    
    func addWord() {
        let trimmed = newWord.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !settings.customDictionary.contains(trimmed) {
            settings.customDictionary.append(trimmed)
            newWord = ""
        }
    }
    
    func removeWord(_ word: String) {
        settings.customDictionary.removeAll { $0 == word }
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
            ForEach(downloaded) { model in
                Text("\(model.label)  \(model.estimatedSize)").tag(model.id)
            }
        }
        .pickerStyle(.menu)
    }
}
