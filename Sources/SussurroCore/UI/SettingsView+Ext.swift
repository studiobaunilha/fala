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
