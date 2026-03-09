import SwiftUI

extension TranscribeView {
    var batchQueueSection: some View {
        Section {
            ForEach(job.queue) { item in
                BatchQueueRowView(
                    item: item,
                    isWorking: isWorking,
                    onReveal: { job.revealOutput(for: item.id) },
                    onRemove: {
                        withAnimation(AnimationConfig.standard) {
                            job.removeQueueItem(item.id)
                        }
                    }
                )
            }

            HStack {
                Button(L10n("Adicionar Arquivos…")) {
                    job.selectFile()
                }
                .disabled(isWorking)

                Spacer()

                if !isWorking {
                    Button(L10n("Limpar Fila")) {
                        withAnimation(AnimationConfig.standard) {
                            job.clearQueue()
                        }
                    }
                }
            }
        } header: {
            Text(L10n("Fila de Arquivos"))
        } footer: {
            Text(L10n("Os arquivos serão processados em sequência usando as opções abaixo."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    func activeStatusView(message: String, progressText: String? = nil) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                StatusBanner(message: message)

                if let activeQueueProgressLine {
                    Text(activeQueueProgressLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let progressText, !progressText.isEmpty {
                    ScrollView {
                        Text(progressText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, Spacing.sm)
                    }
                    .frame(maxHeight: LayoutMetric.progressLogMaxHeight)
                }
            }

            Spacer()

            Button(role: .cancel, action: { job.cancel() }, label: {
                Image(systemName: "stop.circle.fill")
                    .foregroundColor(FalaColors.error)
            })
            .buttonStyle(.plain)
            .controlSize(.large)
        }
    }

    func queueSummaryView(
        title: String,
        systemImage: String,
        tint: Color,
        detail: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(tint)

            Text(L10n("Resumo da fila"))
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(queueSummaryLine)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                if job.completedOutputDirectory != nil {
                    Button(L10n("Mostrar no Finder")) {
                        job.revealOutputDirectory()
                    }
                }

                if job.hasRetryableQueueItems {
                    Button(L10n("Retentar Itens Pendentes")) {
                        job.transcribe()
                    }
                }

                Button(L10n("Nova Fila")) {
                    withAnimation(AnimationConfig.standard) {
                        job.clearQueue()
                    }
                }
            }
            .padding(.top, Spacing.xs)
        }
    }

    var primaryActionTitle: String {
        if job.hasMultipleQueuedFiles {
            if job.completedQueueCount > 0 && job.hasRetryableQueueItems {
                return L10n("Retentar Itens Pendentes")
            }
            return L10n("Iniciar Fila")
        }

        return L10n("Iniciar Transcrição")
    }

    var queueSummaryLine: String {
        String(
            format: L10n("Concluídos: %d · Falhas: %d · Cancelados: %d"),
            job.completedQueueCount,
            job.failedQueueCount,
            job.cancelledQueueCount
        )
    }

    var activeQueueProgressLine: String? {
        guard let ordinal = job.activeQueueOrdinal else { return nil }
        return String(
            format: L10n("Arquivo %d de %d"),
            ordinal,
            job.queue.count
        )
    }
}

private struct BatchQueueRowView: View {
    let item: BatchQueueItem
    let isWorking: Bool
    let onReveal: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            iconView
            detailsView
            Spacer()
            actionView
        }
        .padding(.vertical, Spacing.xs)
    }

    private var iconView: some View {
        Image(systemName: statusIcon)
            .font(.system(size: LayoutMetric.transcribeDocumentGlyphSize))
            .foregroundStyle(statusTint)
            .frame(
                width: LayoutMetric.transcribeDocumentIconSize,
                height: LayoutMetric.transcribeDocumentIconSize
            )
            .background(statusTint.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
    }

    private var detailsView: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(item.inputURL.lastPathComponent)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)

            Text(statusTitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            if case .transcribing(let progressText) = item.status, !progressText.isEmpty {
                Text(progressText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if case .done(let outputURL, let warning) = item.status {
                Text(outputURL.lastPathComponent)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                if let warning {
                    Text(warning.title)
                        .font(.caption2)
                        .foregroundStyle(FalaColors.warning)
                        .lineLimit(2)
                }
            }
        }
    }

    @ViewBuilder
    private var actionView: some View {
        if case .done = item.status {
            Button(L10n("Mostrar no Finder")) {
                onReveal()
            }
            .buttonStyle(.link)
            .controlSize(.small)
        } else if !isWorking {
            Button(role: .destructive) {
                onRemove()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
        }
    }

    private var statusTitle: String {
        switch item.status {
        case .pending:
            return L10n("Aguardando na fila")
        case .converting:
            return L10n("Preparando arquivo de áudio…")
        case .preparingModel:
            return L10n("Preparando motor de transcrição…")
        case .transcribing:
            return L10n("Transcrevendo…")
        case .processingLLM:
            return L10n("Aprimorando com IA (LLM)…")
        case .done:
            return L10n("Transcrição Concluída")
        case .error(let message):
            return message
        case .cancelled:
            return L10n("Cancelado pelo usuário")
        }
    }

    private var statusIcon: String {
        switch item.status {
        case .pending:
            return "list.bullet.clipboard"
        case .converting:
            return "waveform"
        case .preparingModel:
            return "cpu"
        case .transcribing:
            return "waveform.and.magnifyingglass"
        case .processingLLM:
            return "wand.and.stars"
        case .done:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        case .cancelled:
            return "xmark.circle.fill"
        }
    }

    private var statusTint: Color {
        switch item.status {
        case .pending:
            return .accentColor
        case .converting, .preparingModel, .transcribing, .processingLLM:
            return FalaColors.info
        case .done:
            return FalaColors.success
        case .error:
            return FalaColors.error
        case .cancelled:
            return .secondary
        }
    }
}
