import SwiftUI

// MARK: – View Components (Extension)

extension TranscribeView {
    private var batchReadinessIssue: ReadinessIssue? {
        job.appSettings.readiness.primaryIssueForBatch(batchPrompt: job.batchPostPrompt)
    }
    
    private var defaultModelLabel: String {
        let activeWhisperModel = job.appSettings.activeWhisperModel
        let modelName = knownModels.first { $0.id == activeWhisperModel }?.label
            ?? activeWhisperModel
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
                .font(.system(size: LayoutMetric.transcribeEmptyStateIconSize, weight: .light))
                .foregroundColor(.accentColor)
                .padding(.bottom, Spacing.sm)
            
            Text(L10n("Arraste e solte arquivos de áudio aqui"))
                .font(.title2)
                .fontWeight(.medium)
            
            Text(L10n("Ou selecione um ou mais arquivos para iniciar a transcrição em lote."))
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: LayoutMetric.transcribeEmptyStateTextMaxWidth)
            
            Button(L10n("Selecionar Arquivos…")) {
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
            batchQueueSection

            Section {
                PromptEditorPanel(
                    text: $job.batchPostPrompt,
                    placeholder: L10n("Ex: Corrija pontuação e gramática..."),
                    minHeight: LayoutMetric.batchPromptMinHeight,
                    isDisabled: isWorking
                )
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
            } header: {
                Text(L10n("Modelo & Qualidade"))
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
            if let issue = batchReadinessIssue {
                NoticeCard(
                    title: issue.title,
                    message: issue.message,
                    tone: .warning
                ) {
                    if let actionTitle = issue.actionTitle {
                        Button(actionTitle) {
                            performReadinessAction(issue)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            } else if licenseManager.isActivated {
                VStack(spacing: Spacing.md) {
                    Button(primaryActionTitle) {
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
                NoticeCard(
                    title: licenseManager.accessState == .needsConnection
                        ? L10n("Conexão Necessária")
                        : L10n("Período de Teste Esgotado"),
                    message: licenseManager.accessState == .needsConnection
                        ? L10n(
                            "Conecte este Mac e valide a licença nos Ajustes para voltar a transcrever arquivos."
                        )
                        : L10n("Ative o Fala Pro nos Ajustes para voltar a transcrever arquivos."),
                    tone: .error,
                    textAlignment: .center
                )
            }

        case .converting:
            activeStatusView(message: L10n("Preparando arquivo de áudio…"))

        case .transcribing(let progressText):
            activeStatusView(
                message: L10n("Transcrevendo…"),
                progressText: progressText
            )
            
        case .processingLLM:
            activeStatusView(message: L10n("Aprimorando com IA (LLM)…"))

        case .done(let path):
            if job.hasMultipleQueuedFiles {
                queueSummaryView(
                    title: job.failedQueueCount > 0 || job.cancelledQueueCount > 0
                        ? L10n("Fila concluída com pendências")
                        : L10n("Fila concluída"),
                    systemImage: job.failedQueueCount > 0 || job.cancelledQueueCount > 0
                        ? "exclamationmark.triangle.fill"
                        : "checkmark.circle.fill",
                    tint: job.failedQueueCount > 0 || job.cancelledQueueCount > 0
                        ? FalaColors.warning
                        : FalaColors.success
                )
            } else {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    if let warning = job.processingWarning {
                        NoticeCard(
                            title: warning.title,
                            message: warning.message,
                            tone: .warning
                        )
                    }

                    Label(L10n("Transcrição Concluída"), systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(FalaColors.success)
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
            }

        case .error(let message):
            errorView(message: message)
        }
    }
    
    @ViewBuilder
    private func errorView(message: String) -> some View {
        Group {
            if job.hasMultipleQueuedFiles {
                let isCanceled = message == L10n("Cancelado pelo usuário")
                queueSummaryView(
                    title: isCanceled ? L10n("Fila interrompida") : L10n("Fila concluída com pendências"),
                    systemImage: isCanceled ? "xmark.circle.fill" : "exclamationmark.triangle.fill",
                    tint: isCanceled ? .secondary : FalaColors.warning,
                    detail: isCanceled ? nil : message
                )
            } else {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    let isCanceled = message == L10n("Cancelado pelo usuário")
                    Label(isCanceled ? L10n("Transcrição Cancelada") : L10n("Falha na Transcrição"),
                          systemImage: isCanceled ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(isCanceled ? Color.secondary : FalaColors.error)
                    
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
    }

    private func performReadinessAction(_ issue: ReadinessIssue) {
        switch issue.action {
        case .none:
            return
        case .openSettings(let selection):
            job.appSettings.openSettings(selection)
        case .openMicrophoneSettings:
            if job.appSettings.permissionProvider.microphonePermissionState() == .notDetermined {
                Task {
                    _ = await job.appSettings.permissionProvider.requestMicrophoneAccess()
                    job.appSettings.readiness.refresh()
                }
            } else {
                job.appSettings.permissionProvider.openMicrophoneSettings()
            }
        case .openAccessibilitySettings:
            job.appSettings.permissionProvider.openAccessibilitySettings()
        case .validateLicense:
            Task {
                await licenseManager.refreshEntitlement()
                job.appSettings.readiness.refresh()
            }
        }
    }
}
