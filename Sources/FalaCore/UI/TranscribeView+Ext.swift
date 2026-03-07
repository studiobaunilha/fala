import SwiftUI

// MARK: – View Components (Extension)

extension TranscribeView {
    
    private var defaultModelLabel: String {
        let modelName = knownModels.first { $0.id == job.appSettings.batchModel }?.label
            ?? job.appSettings.batchModel
        return "\(L10n("Usar padrão dos Ajustes")) (\(modelName))"
    }
    
    private var defaultLanguageLabel: String {
        let langName = job.appSettings.transcriptionLanguageName(
            for: job.appSettings.transcriptionLanguage
        )
        return "\(L10n("Usar padrão dos Ajustes")) (\(langName))"
    }
    
    var emptyStateView: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "waveform.badge.plus")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.accentColor)
                .padding(.bottom, Spacing.sm)
            
            Text(L10n("Arraste e solte um arquivo de áudio aqui"))
                .font(.title2)
                .fontWeight(.medium)
            
            Text(L10n("Ou selecione um arquivo para iniciar a transcrição de alta precisão."))
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            
            Button(L10n("Selecionar Arquivo…")) {
                job.selectFile()
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .padding(.top, Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    var formView: some View {
        Form {
            Section(L10n("Arquivo")) {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "doc.audio.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.accentColor)
                        .frame(width: 40, height: 40)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(8)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(job.inputURL?.lastPathComponent ?? "")
                            .font(.headline)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        Text(L10n("Pronto para transcrever"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(L10n("Trocar...")) { job.selectFile() }
                        .disabled(isWorking)
                }
                .padding(.vertical, Spacing.xs)
            }

            Section {
                TextEditor(text: $job.batchPostPrompt)
                    .frame(minHeight: 80)
                    .font(.body.monospaced())
                    .scrollContentBackground(.hidden)
                    .padding(Spacing.xs)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .stroke(Color(nsColor: .separatorColor))
                    )
                    .disabled(isWorking)
                    .overlay(alignment: .topLeading) {
                        if job.batchPostPrompt.isEmpty {
                            Text(L10n("Ex: Corrija pontuação e gramática..."))
                                .foregroundStyle(.tertiary)
                                .font(.body.monospaced())
                                .padding(.horizontal, Spacing.sm)
                                .padding(.vertical, Spacing.xs + 4)
                                .allowsHitTesting(false)
                        }
                    }
            } header: {
                Text(L10n("Pós-processamento com IA (opcional)"))
            } footer: {
                // swiftlint:disable:next line_length
                Text(L10n("Deixe vazio para transcrição pura. Preencha com instruções para processar o texto via IA após a transcrição."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                if job.appSettings.transcriptionEngine == "whisper" {
                    Picker(L10n("Modelo"), selection: $job.overrideModel) {
                        Text(defaultModelLabel).tag(nil as String?)
                        Divider()
                        ForEach(knownModels) { model in
                            Text(model.label).tag(model.id as String?)
                        }
                    }
                    .disabled(isWorking)
                } else {
                    LabeledContent(L10n("Motor")) {
                        Text(L10n("Parakeet V3"))
                            .foregroundStyle(.secondary)
                    }
                }

                if job.appSettings.supportsExplicitEngineLanguageSelection {
                    Picker(L10n("Idioma do Áudio"), selection: $job.overrideLanguage) {
                        Text(defaultLanguageLabel).tag(nil as String?)
                        Divider()
                        ForEach(job.appSettings.availableLanguagesForEngine) { lang in
                            Text(lang.name).tag(lang.id as String?)
                        }
                    }
                    .disabled(isWorking)
                } else {
                    LabeledContent(L10n("Idioma do Áudio")) {
                        Text(L10n("Detecção automática"))
                            .foregroundStyle(.secondary)
                    }
                }
                
                Toggle(L10n("Identificar múltiplos locutores (Diarization)"), isOn: $job.appSettings.enableDiarization)
                    .disabled(isWorking || job.appSettings.llmProvider == "apple")
            } header: {
                Text(L10n("Modelo & Qualidade"))
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    // swiftlint:disable:next line_length
                    Text(L10n("A identificação de locutores funciona via pós-processamento com IA — não é detecção acústica. A qualidade depende do modelo de IA selecionado. Requer o campo de pós-processamento preenchido."))
                        .foregroundStyle(.secondary)
                    
                    if job.appSettings.llmProvider == "apple" {
                        // swiftlint:disable:next line_length
                        Label(L10n("Indisponível com Apple Intelligence (requer modelo mais avançado)"), systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
                .font(.caption)
            }

            Section(L10n("Saída")) {
                Picker(L10n("Formato"), selection: $job.outputFormat) {
                    Text(L10n("Texto (.txt)")).tag("txt")
                    Text(L10n("Markdown (.md)")).tag("md")
                }
                .disabled(isWorking)
                
                HStack {
                    Text(L10n("Salvar em:"))
                    Spacer()
                    Text(job.outputDirectory?.lastPathComponent ?? L10n("Mesma Pasta do Original"))
                        .foregroundColor(.secondary)
                    Button(L10n("Alterar...")) { job.selectOutputDirectory() }
                        .disabled(isWorking)
                }
            }

            Section {
                statusView
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    var statusView: some View {
        switch job.state {
        case .idle:
            if licenseManager.isActivated {
                VStack(spacing: 8) {
                    Button(L10n("Iniciar Transcrição")) {
                        job.transcribe()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    
                    if licenseManager.isTrialActive {
                        Text(
                            String(
                                format: L10n("Modo Trial (%d dias restantes)"),
                                licenseManager.trialDaysRemaining
                            )
                        )
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                VStack(spacing: 4) {
                    Text(
                        licenseManager.accessState == .needsConnection
                            ? L10n("Conexão Necessária")
                            : L10n("Período de Teste Esgotado")
                    )
                        .font(.headline)
                        .foregroundColor(.red)
                    Text(
                        licenseManager.accessState == .needsConnection
                            ? L10n(
                                "Conecte este Mac e valide a licença nos Ajustes para voltar a transcrever arquivos."
                            )
                            : L10n("Ative o Fala Pro nos Ajustes para voltar a transcrever arquivos.")
                    )
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }

        case .converting:
            HStack {
                StatusBanner(message: L10n("Preparando arquivo de áudio…"))
                Spacer()
                Button(role: .cancel, action: { job.cancel() }, label: {
                    Image(systemName: "stop.circle.fill")
                        .foregroundColor(.red)
                })
                .buttonStyle(.plain)
                .controlSize(.large)
            }

        case .transcribing(let progressText):
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    StatusBanner(message: L10n("Transcrevendo…"))
                    if !progressText.isEmpty {
                        ScrollView {
                            Text(progressText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, Spacing.sm)
                        }
                        .frame(maxHeight: 200)
                    }
                }
                Spacer()
                Button(role: .cancel, action: { job.cancel() }, label: {
                    Image(systemName: "stop.circle.fill")
                        .foregroundColor(.red)
                })
                .buttonStyle(.plain)
                .controlSize(.large)
            }
            
        case .processingLLM:
            HStack {
                StatusBanner(message: L10n("Aprimorando com IA (LLM)…"))
                Spacer()
                Button(role: .cancel, action: { job.cancel() }, label: {
                    Image(systemName: "stop.circle.fill")
                        .foregroundColor(.red)
                })
                .buttonStyle(.plain)
                .controlSize(.large)
            }

        case .done(let path):
            VStack(alignment: .leading, spacing: Spacing.md) {
                Label(L10n("Transcrição Concluída"), systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(Color.green)
                Text(path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                HStack {
                    Button(L10n("Mostrar no Finder")) { job.revealInFinder() }
                    Button(L10n("Nova Transcrição")) {
                        withAnimation(AnimationConfig.standard) {
                            job.reset()
                        }
                    }
                }
                .padding(.top, Spacing.xs)
            }

        case .error(let message):
            errorView(message: message)
        }
    }
    
    @ViewBuilder
    private func errorView(message: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            let isCanceled = message == L10n("Cancelado pelo usuário")
            Label(isCanceled ? L10n("Transcrição Cancelada") : L10n("Falha na Transcrição"),
                  systemImage: isCanceled ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(isCanceled ? Color.secondary : Color.red)
            
            if !isCanceled {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Button(L10n("Tentar Novamente")) {
                withAnimation(AnimationConfig.standard) {
                    job.state = .idle
                }
            }
            .padding(.top, Spacing.xs)
        }
    }
}
