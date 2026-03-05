import SwiftUI

extension SettingsView {

    var llmView: some View {
        Form {
            Section {
                Picker(L10n("Provedor Padrão"), selection: $settings.llmProvider) {
                    Text("Google Gemini").tag("gemini")
                    Text("OpenAI").tag("openai")
                    Text("Apple Intelligence").tag("apple")
                    Text("MLX Local").tag("mlx")
                }
            } header: {
                Text(L10n("Provedor de IA"))
            } footer: {
                providerFooterText
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if settings.llmProvider != "apple" {
                Section {
                    TextEditor(text: $settings.globalSystemPrompt)
                        .frame(minHeight: 120)
                        .font(.body.monospaced())
                        .scrollContentBackground(.hidden)
                        .padding(Spacing.xs)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .stroke(Color(nsColor: .separatorColor))
                        )
                    
                    let isModified = settings.globalSystemPrompt != AppConfig.defaultGlobalSystemPrompt
                    HStack {
                        Button(L10n("Restaurar Padrão")) {
                            settings.globalSystemPrompt = AppConfig.defaultGlobalSystemPrompt
                        }
                        .disabled(!isModified)
                        
                        Spacer()
                        
                        if isModified {
                            Label(L10n("Modificado"), systemImage: "pencil.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                } header: {
                    Text(L10n("Prompt de Sistema Global (Pós-processamento)"))
                } footer: {
                    // swiftlint:disable:next line_length
                    Text(L10n("Anexado no final de todas as instruções. Serve para forçar a IA a agir estritamente como formatadora, sem preâmbulos."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if settings.llmProvider == "gemini" {
                geminiCredentialsSection
            } else if settings.llmProvider == "openai" {
                openAICredentialsSection
            } else if settings.llmProvider == "apple" {
                appleIntelligenceSection
            } else if settings.llmProvider == "mlx" {
                mlxConfigSection
                mlxModelsSection
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

    // MARK: - Provider Descriptions

    private var providerFooterText: Text {
        switch settings.llmProvider {
        case "apple":
            // swiftlint:disable:next line_length
            return Text(L10n("Apple Intelligence roda 100% no dispositivo, sem custos. Melhor para tarefas simples (limpar, formatar)."))
        case "mlx":
            // swiftlint:disable:next line_length
            return Text(L10n("Modelos MLX rodam localmente no Apple Silicon. Suportam prompts complexos dependendo do modelo escolhido."))
        case "gemini":
            // swiftlint:disable:next line_length
            return Text(L10n("Requer chave API gratuita. Suporta todos os modos e prompts complexos com alta qualidade."))
        case "openai":
            return Text(L10n("Requer chave API paga. Suporta todos os modos e prompts complexos com alta qualidade."))
        default:
            return Text(L10n("Este é o provedor padrão global. Modos individuais podem sobrescrever esta escolha."))
        }
    }

    private var appleIntelligenceSection: some View {
        Section(L10n("Apple Intelligence")) {
            appleAvailabilityRow

            Label {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(L10n("Modelo compacto (~3B parâmetros)"))
                        .font(.body)
                    // swiftlint:disable:next line_length
                    Text(L10n("Ideal para tarefas simples como limpar e formatar texto. Para prompts criativos ou complexos (Dev, Sumário), considere Gemini, OpenAI ou MLX."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "info.circle")
                    .foregroundStyle(.blue)
            }
            .padding(.vertical, Spacing.xs)
        }
    }

    private var appleAvailabilityRow: some View {
        Group {
            #if canImport(FoundationModels)
            if #available(macOS 26, *) {
                AppleIntelligenceStatusView()
            } else {
                unavailableRow(L10n("Requer macOS Tahoe (26) ou superior."))
            }
            #else
            unavailableRow(L10n("Requer macOS Tahoe (26) ou superior. Compile com o SDK do macOS 26."))
            #endif
        }
    }

    private func unavailableRow(_ message: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(L10n("Indisponível"))
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
        Section(L10n("MLX Local")) {
            LabeledContent(L10n("Modelo Padrão")) {
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
                    .help(L10n("Selecionar modelo conhecido"))
                }
            }

            Text(L10n("Os modelos MLX rodam localmente no Apple Silicon. Baixe pelo menos um modelo abaixo."))
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
            Text(L10n("Modelos MLX Locais"))
        } footer: {
            // swiftlint:disable:next line_length
            Text(L10n("Modelos LLM para processamento local via MLX. Rodam inteiramente no dispositivo usando Apple Silicon."))
                .font(.caption)
                .foregroundStyle(.secondary)
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
                    .frame(width: 16)
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
