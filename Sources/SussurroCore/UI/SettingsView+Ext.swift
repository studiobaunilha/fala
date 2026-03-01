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
    
    var llmView: some View {
        Form {
            Section {
                Toggle("Habilitar IA de Pós-processamento", isOn: $settings.enableLLMPostProcessing)
                Toggle("Memória de Contexto Contínuo", isOn: $settings.enableContextBuffer)
            } footer: {
                Text("Usa inteligência artificial para formatar e processar transcrições. " +
                     "A memória de contexto melhora a coesão baseando-se em transcrições anteriores.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if settings.enableLLMPostProcessing {
                Section("Provedor de IA") {
                    Picker("Provedor", selection: $settings.llmProvider) {
                        Text("Google Gemini (Gratuito)").tag("gemini")
                        Text("OpenAI").tag("openai")
                        Text("Apple Intelligence / Local").tag("apple")
                    }
                    .pickerStyle(.menu)
                }
                
                if settings.llmProvider != "apple" {
                    Section("Credenciais") {
                        if settings.llmProvider == "gemini" {
                            LabeledContent("Chave API") {
                                HStack(spacing: Spacing.sm) {
                                    SecureField("Cole sua chave aqui", text: $settings.geminiKey)
                                        .textFieldStyle(.roundedBorder)
                                    
                                    Button(action: {
                                        Task { await testKey(provider: "gemini", key: settings.geminiKey) }
                                    }, label: {
                                        if isTestingKey {
                                            ProgressView().controlSize(.small)
                                        } else {
                                            Text("Testar")
                                        }
                                    })
                                    .disabled(settings.geminiKey.isEmpty || isTestingKey)
                                }
                            }
                            .help("Sua chave do Google AI Studio")

                            HStack {
                                Text("A API do Gemini 2.5 Flash é rápida e possui um nível gratuito generoso.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if let url = URL(string: "https://aistudio.google.com/app/apikey") {
                                    Link("Obter chave gratuita", destination: url)
                                        .font(.caption)
                                }
                            }
                            
                            LabeledContent("Modelo:") {
                                HStack(spacing: Spacing.xs) {
                                    TextField("", text: $settings.geminiModel)
                                        .textFieldStyle(.roundedBorder)
                                    
                                    Menu {
                                        ForEach(availableGeminiModels, id: \.self) { model in
                                            Button(model) {
                                                settings.geminiModel = model
                                            }
                                        }
                                    } label: {
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.caption)
                                    }
                                    .frame(width: 16)
                                    .disabled(availableGeminiModels.isEmpty)
                                    .help("Selecionar modelo disponível")
                                }
                            }
                        } else if settings.llmProvider == "openai" {
                            LabeledContent("Chave API") {
                                HStack(spacing: Spacing.sm) {
                                    SecureField("Cole sua chave aqui", text: $settings.openAIKey)
                                        .textFieldStyle(.roundedBorder)
                                    
                                    Button(action: {
                                        Task { await testKey(provider: "openai", key: settings.openAIKey) }
                                    }, label: {
                                        if isTestingKey {
                                            ProgressView().controlSize(.small)
                                        } else {
                                            Text("Testar")
                                        }
                                    })
                                    .disabled(settings.openAIKey.isEmpty || isTestingKey)
                                }
                            }

                            HStack {
                                Text("A API da OpenAI requer saldo na sua conta de desenvolvedor.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if let url = URL(string: "https://platform.openai.com/api-keys") {
                                    Link("Obter chave", destination: url)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
                
                Section {
                    TextField("Como a IA deve formatar o texto?", text: $settings.llmPrompt, axis: .vertical)
                        .lineLimit(4...8)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text("Instrução (System Prompt)")
                } footer: {
                    Text("Deixe em branco para usar o prompt padrão do sistema.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Pós-processamento (IA)")
        .alert("Resultado do Teste", isPresented: $showTestKeyAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            if let result = testKeyResult {
                Text(result)
            }
        }
    }
    
    func testKey(provider: String, key: String) async {
        isTestingKey = true
        defer { isTestingKey = false }
        
        do {
            if provider == "gemini" {
                try await testGeminiKey(key)
            } else {
                try await testOpenAIKey(key)
            }
        } catch {
            testKeyResult = "Falha no teste: \(error.localizedDescription)"
        }
        
        showTestKeyAlert = true
    }
    
    private func testGeminiKey(_ key: String) async throws {
        let baseUrl = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent"
        guard let url = URL(string: "\(baseUrl)?key=\(key)") else { throw URLError(.badURL) }
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["contents": [["parts": [["text": "Hi"]]]]]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: req)
        
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        
        if http.statusCode == 200 {
            testKeyResult = "Sucesso! A chave do Gemini está funcionando."
            return
        }
        
        if http.statusCode == 404 {
            try await checkGeminiModelsList(key)
            return
        }
        
        let errBody = String(data: data, encoding: .utf8) ?? "Erro desconhecido"
        let msg = "Erro \(http.statusCode): \(errBody)"
        throw NSError(domain: "API", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
    }
    
    private func checkGeminiModelsList(_ key: String) async throws {
        guard let listUrl = URL(string: "https://generativelanguage.googleapis.com/v1beta/models?key=\(key)") else {
             throw URLError(.badURL)
        }
        
        let (listData, listResp) = try await URLSession.shared.data(from: listUrl)
        guard let listHttp = listResp as? HTTPURLResponse, listHttp.statusCode == 200 else {
            throw NSError(domain: "API", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Modelo não encontrado e falha ao listar modelos."
            ])
        }
        
        if let json = try JSONSerialization.jsonObject(with: listData) as? [String: Any],
           let models = json["models"] as? [[String: Any]] {
            let names = models.compactMap { ($0["name"] as? String)?.components(separatedBy: "/").last }
            self.availableGeminiModels = names
            testKeyResult = "Chave válida. Lista de modelos atualizada."
        } else {
            testKeyResult = "Chave válida, mas erro ao listar modelos."
        }
    }

    private func testOpenAIKey(_ key: String) async throws {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else { throw URLError(.badURL) }
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [["role": "user", "content": "Hi"]],
            "max_tokens": 5
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        
        if http.statusCode != 200 {
            let errBody = String(data: data, encoding: .utf8) ?? "Erro desconhecido"
            let msg = "Erro \(http.statusCode): \(errBody)"
            throw NSError(domain: "API", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        
        testKeyResult = "Sucesso! A chave da OpenAI está funcionando."
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
