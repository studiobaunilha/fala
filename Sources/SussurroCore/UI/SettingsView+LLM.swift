import SwiftUI

extension SettingsView {
    
    var llmView: some View {
        Form {
            Section {
                Picker("Provedor Padrão", selection: $settings.llmProvider) {
                    Text("Google Gemini").tag("gemini")
                    Text("OpenAI").tag("openai")
                    Text("Apple Intelligence (em breve)").tag("apple")
                }
            } header: {
                Text("Provedor de IA")
            } footer: {
                Text("Este é o provedor padrão global. Modos individuais podem sobrescrever esta escolha.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if settings.llmProvider == "gemini" {
                geminiCredentialsSection
            } else if settings.llmProvider == "openai" {
                openAICredentialsSection
            }

            Section {
                Toggle("Memória de Contexto Contínuo", isOn: $settings.enableContextBuffer)
            } footer: {
                Text("Mantém notas da IA sobre tom, assunto e vocabulário " +
                     "para melhorar transcrições ao longo da sessão.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if settings.enableContextBuffer {
                Section {
                    TextEditor(text: $contextManager.summary)
                        .font(.body)
                        .frame(minHeight: 100)
                        .scrollContentBackground(.hidden)
                        .padding(Spacing.xs)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .stroke(Color(nsColor: .separatorColor))
                        )

                    HStack {
                        Spacer()
                        Button("Limpar Memória") {
                            contextManager.clear()
                        }
                        .disabled(contextManager.summary.isEmpty)
                    }
                } header: {
                    Text("Memória de Contexto")
                } footer: {
                    Text("Notas da IA sobre a sessão atual. São usadas para refinar futuras transcrições.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("IA & LLM")
        .alert("Resultado do Teste", isPresented: $showTestKeyAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            if let result = testKeyResult {
                Text(result)
            }
        }
    }

    private var geminiCredentialsSection: some View {
        Section("Credenciais — Gemini") {
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

            LabeledContent("Modelo") {
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
        }
    }

    private var openAICredentialsSection: some View {
        Section("Credenciais — OpenAI") {
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
}
