import SwiftUI

// MARK: – View Components (Extension)

extension TranscribeView {
    
    var emptyStateView: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "waveform.badge.plus")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.accentColor)
                .padding(.bottom, Spacing.sm)
            
            Text("Arraste e solte um arquivo de áudio aqui")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Ou selecione um arquivo para iniciar a transcrição de alta precisão.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            
            Button("Selecionar Arquivo…") {
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
            Section("Arquivo") {
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
                        
                        Text("Pronto para transcrever")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Trocar...") { job.selectFile() }
                        .disabled(isWorking)
                }
                .padding(.vertical, Spacing.xs)
            }

            Section("Modo de Processamento") {
                Picker("Modo", selection: $job.selectedTemplate) {
                    ForEach(DictationTemplate.allCases, id: \.self) { template in
                        Label(template.rawValue, systemImage: template.icon)
                            .tag(template)
                    }
                }
                .disabled(isWorking)
            }

            Section("Modelo & Qualidade") {
                Picker("Modelo", selection: $job.overrideModel) {
                    Text("Usar Padrão do Sistema").tag(nil as String?)
                    Divider()
                    ForEach(knownModels) { model in
                        Text(model.label).tag(model.id as String?)
                    }
                }
                .disabled(isWorking)
                
                Picker("Idioma", selection: $job.overrideLanguage) {
                    Text("Usar Padrão do Sistema").tag(nil as String?)
                    Divider()
                    ForEach(AppSettings.languages) { lang in
                        Text(lang.name).tag(lang.id as String?)
                    }
                }
                .disabled(isWorking)
                
                Toggle("Identificar múltiplos locutores (Diarization)", isOn: $job.enableDiarization)
                    .disabled(isWorking)
            }

            Section("Saída") {
                Picker("Formato", selection: $job.outputFormat) {
                    Text("Texto (.txt)").tag("txt")
                    Text("Markdown (.md)").tag("md")
                }
                .disabled(isWorking)
                
                HStack {
                    Text("Salvar em:")
                    Spacer()
                    Text(job.outputDirectory?.lastPathComponent ?? "Mesma Pasta do Original")
                        .foregroundColor(.secondary)
                    Button("Alterar...") { job.selectOutputDirectory() }
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
            Button("Iniciar Transcrição") {
                job.transcribe()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)

        case .converting:
            HStack {
                StatusBanner(message: "Preparando arquivo de áudio…")
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
                    StatusBanner(message: "Transcrevendo…")
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
                StatusBanner(message: "Aprimorando com IA (LLM)…")
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
                Label("Transcrição Concluída", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(Color.green)
                Text(path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                HStack {
                    Button("Mostrar no Finder") { job.revealInFinder() }
                    Button("Nova Transcrição") {
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
            let isCanceled = message == "Cancelado pelo usuário"
            Label(isCanceled ? "Transcrição Cancelada" : "Falha na Transcrição",
                  systemImage: isCanceled ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(isCanceled ? Color.secondary : Color.red)
            
            if !isCanceled {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Button("Tentar Novamente") {
                withAnimation(AnimationConfig.standard) {
                    job.state = .idle
                }
            }
            .padding(.top, Spacing.xs)
        }
    }
}
