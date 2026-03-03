import SwiftUI

extension SettingsView {

    var llmView: some View {
        Form {
            Section {
                Picker("Provedor Padrão", selection: $settings.llmProvider) {
                    Text("Google Gemini").tag("gemini")
                    Text("OpenAI").tag("openai")
                    Text("Apple Intelligence").tag("apple")
                    Text("MLX Local").tag("mlx")
                }
            } header: {
                Text("Provedor de IA")
            } footer: {
                Text("Este é o provedor padrão global. "
                     + "Modos individuais podem sobrescrever esta escolha.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if settings.llmProvider == "gemini" {
                geminiCredentialsSection
            } else if settings.llmProvider == "openai" {
                openAICredentialsSection
            } else if settings.llmProvider == "apple" {
                appleIntelligenceSection
            } else if settings.llmProvider == "mlx" {
                mlxConfigSection
            }

            mlxModelsSection
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

    // MARK: - Apple Intelligence

    private var appleIntelligenceSection: some View {
        Section("Apple Intelligence") {
            appleAvailabilityRow
        }
    }

    private var appleAvailabilityRow: some View {
        Group {
            #if canImport(FoundationModels)
            if #available(macOS 26, *) {
                AppleIntelligenceStatusView()
            } else {
                unavailableRow("Requer macOS Tahoe (26) ou superior.")
            }
            #else
            unavailableRow("Requer macOS Tahoe (26) ou superior. "
                           + "Compile com o SDK do macOS 26.")
            #endif
        }
    }

    private func unavailableRow(_ message: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Indisponível")
                    .font(.body)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
        }
        .padding(.vertical, Spacing.xs)
    }

    // MARK: - MLX Config

    private var mlxConfigSection: some View {
        Section("MLX Local") {
            LabeledContent("Modelo Padrão") {
                HStack(spacing: Spacing.xs) {
                    TextField("", text: $settings.mlxModel)
                        .textFieldStyle(.roundedBorder)

                    Menu {
                        ForEach(knownMLXModels) { model in
                            Button(model.label) {
                                settings.mlxModel = model.repoID
                            }
                        }
                    } label: {
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                    }
                    .frame(width: 16)
                    .help("Selecionar modelo conhecido")
                }
            }

            Text("Os modelos MLX rodam localmente no Apple Silicon. "
                 + "Baixe pelo menos um modelo abaixo.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - MLX Models Download

    private var mlxModelsSection: some View {
        Section {
            ForEach(knownMLXModels) { model in
                MLXModelRow(
                    model: model,
                    manager: settings.mlxModelManager,
                    isSelected: settings.mlxModel == model.repoID
                )
            }
        } header: {
            Text("Modelos MLX Locais")
        } footer: {
            Text("Modelos LLM para processamento local via MLX. "
                 + "Rodam inteiramente no dispositivo usando Apple Silicon.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Gemini Credentials

    private var geminiCredentialsSection: some View {
        Section("Credenciais — Gemini") {
            LabeledContent("Chave API") {
                HStack(spacing: Spacing.sm) {
                    SecureField("Cole sua chave aqui",
                                text: $settings.geminiKey)
                        .textFieldStyle(.roundedBorder)

                    Button(action: {
                        Task {
                            await testKey(provider: "gemini",
                                          key: settings.geminiKey)
                        }
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
                Text("A API do Gemini 2.5 Flash é rápida "
                     + "e possui um nível gratuito generoso.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let url = URL(
                    string: "https://aistudio.google.com/app/apikey"
                ) {
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

    // MARK: - OpenAI Credentials

    private var openAICredentialsSection: some View {
        Section("Credenciais — OpenAI") {
            LabeledContent("Chave API") {
                HStack(spacing: Spacing.sm) {
                    SecureField("Cole sua chave aqui",
                                text: $settings.openAIKey)
                        .textFieldStyle(.roundedBorder)

                    Button(action: {
                        Task {
                            await testKey(provider: "openai",
                                          key: settings.openAIKey)
                        }
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
                Text("A API da OpenAI requer saldo na conta "
                     + "de desenvolvedor.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let url = URL(
                    string: "https://platform.openai.com/api-keys"
                ) {
                    Link("Obter chave", destination: url)
                        .font(.caption)
                }
            }
        }
    }

}
