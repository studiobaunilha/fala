import SwiftUI

extension SettingsView {

    var llmView: some View {
        Form {
            Section {
                Picker(L10n("Provedor Padrão"), selection: $settings.llmProvider) {
                    Text(L10n("Apple Intelligence (Local)")).tag("apple")
                    Text(L10n("MLX Local")).tag("mlx")
                    Text(L10n("Google Gemini (Cloud)")).tag("gemini")
                    Text(L10n("OpenAI (Cloud)")).tag("openai")
                }
            } header: {
                Text(L10n("Provedor de IA"))
            } footer: {
                providerFooterText
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if settings.llmProvider == "apple" {
                appleIntelligenceSection
            } else if settings.llmProvider == "mlx" {
                if let issue = settings.readiness.issuesForDictation().first(where: {
                    $0.kind == .mlxModelMissing
                }) {
                    Section {
                        readinessIssueCard(issue)
                    }
                }
                MLXCatalogSectionsView(settings: settings)
            } else if settings.llmProvider == "gemini" {
                geminiCredentialsSection
            } else if settings.llmProvider == "openai" {
                openAICredentialsSection
            }
        }
        .formStyle(.grouped)
        .navigationTitle(L10n("IA & LLM"))
        .alert(L10n("Resultado do Teste"), isPresented: $showTestKeyAlert) {
            Button(L10n("OK"), role: .cancel) { }
        } message: {
            if let result = testKeyResult {
                Text(result)
            }
        }
    }

    // MARK: - Gemini Credentials

    private var geminiCredentialsSection: some View {
        Section(L10n("Credenciais — Gemini")) {
            LabeledContent(L10n("Chave API")) {
                HStack(spacing: Spacing.sm) {
                    SecureField(L10n("Cole sua chave aqui"),
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
                            Text(L10n("Testar"))
                        }
                    })
                    .disabled(settings.geminiKey.isEmpty || isTestingKey)
                }
            }
            .help(L10n("Sua chave do Google AI Studio"))

            HStack {
                Text(L10n("A API do Gemini 2.5 Flash é rápida e possui um nível gratuito generoso."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let url = URL(
                    string: "https://aistudio.google.com/app/apikey"
                ) {
                    Link(L10n("Obter chave gratuita"), destination: url)
                        .font(.caption)
                }
            }

            LabeledContent(L10n("Modelo")) {
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
                    .frame(width: LayoutMetric.compactPickerIconWidth)
                    .disabled(availableGeminiModels.isEmpty)
                    .help(L10n("Selecionar modelo disponível"))
                }
            }
        }
    }

    // MARK: - OpenAI Credentials

    private var openAICredentialsSection: some View {
        Section(L10n("Credenciais — OpenAI")) {
            LabeledContent(L10n("Chave API")) {
                HStack(spacing: Spacing.sm) {
                    SecureField(L10n("Cole sua chave aqui"),
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
                            Text(L10n("Testar"))
                        }
                    })
                    .disabled(settings.openAIKey.isEmpty || isTestingKey)
                }
            }

            HStack {
                Text(L10n("A API da OpenAI requer saldo na conta de desenvolvedor."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let url = URL(
                    string: "https://platform.openai.com/api-keys"
                ) {
                    Link(L10n("Obter chave"), destination: url)
                        .font(.caption)
                }
            }
        }
    }

}
