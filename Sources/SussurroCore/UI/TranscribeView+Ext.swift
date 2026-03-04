import SwiftUI

// MARK: – View Components (Extension)

extension TranscribeView {
    
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

            Section(L10n("Modo de Processamento")) {
                Picker(L10n("Modo"), selection: $job.selectedTemplate) {
                    ForEach(DictationTemplate.allCases, id: \.self) { template in
                        Label(template.localizedName, systemImage: template.icon)
                            .tag(template)
                    }
                }
                .disabled(isWorking)
            }

            Section(L10n("Modelo & Qualidade")) {
                Picker(L10n("Modelo"), selection: $job.overrideModel) {
                    Text(L10n("Usar Padrão do Sistema")).tag(nil as String?)
                    Divider()
                    ForEach(knownModels) { model in
                        Text(model.label).tag(model.id as String?)
                    }
                }
                .disabled(isWorking)
                
                Picker(L10n("Idioma"), selection: $job.overrideLanguage) {
                    Text(L10n("Usar Padrão do Sistema")).tag(nil as String?)
                    Divider()
                    ForEach(AppSettings.languages) { lang in
                        Text(lang.name).tag(lang.id as String?)
                    }
                }
                .disabled(isWorking)
                
                Toggle(L10n("Identificar múltiplos locutores (Diarization)"), isOn: $job.enableDiarization)
                    .disabled(isWorking)
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
            Button(L10n("Iniciar Transcrição")) {
                job.transcribe()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)

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
