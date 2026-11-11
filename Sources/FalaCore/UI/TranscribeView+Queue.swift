import SwiftUI

extension TranscribeView {
    var batchQueueSection: some View {
        Section {
            ForEach($job.queue) { $item in
                BatchQueueRowView(
                    item: $item,
                    isWorking: isWorking,
                    onReveal: { job.revealOutput(for: item.id) },
                    onCopyRecovery: { job.copyRecoveredTranscript(for: item.id) },
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

                if job.hasMultipleQueuedFiles, let queueProgress {
                    ProgressView(
                        value: Double(queueProgress.completed),
                        total: Double(queueProgress.total)
                    )
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
    @Binding var item: BatchQueueItem
    let isWorking: Bool
    let onReveal: () -> Void
    let onCopyRecovery: () -> Void
    let onRemove: () -> Void
    @State private var showingDetails = false

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
        Image(systemName: item.statusIcon)
            .font(.system(size: LayoutMetric.transcribeDocumentGlyphSize))
            .foregroundStyle(item.statusTint)
            .frame(
                width: LayoutMetric.transcribeDocumentIconSize,
                height: LayoutMetric.transcribeDocumentIconSize
            )
            .background(item.statusTint.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
    }

    private var detailsView: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            titleView
            statusView

            if item.recoverableText != nil {
                Text(L10n("O texto está disponível nesta fila para copiar ou tentar salvar novamente."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if item.displayName != defaultDisplayName {
                Text(item.inputURL.lastPathComponent)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

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

                if let metrics = item.metrics {
                    Text(metrics.humanReadableTotal)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .help(metrics.stageBreakdownTooltip)
                }

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
            HStack {
                if item.recoverableText != nil {
                    Button(L10n("Copiar"), action: onCopyRecovery)
                        .buttonStyle(.link)
                        .controlSize(.small)
                }
                Button(role: .destructive) {
                    onRemove()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var titleView: some View {
        if !isWorking && !item.status.isTerminal {
            TextField("", text: customNameBinding, prompt: Text(defaultDisplayName))
                .textFieldStyle(.roundedBorder)
        } else {
            Text(item.displayName)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    @ViewBuilder
    private var statusView: some View {
        if let metrics = item.metrics, case .done = item.status {
            HStack(spacing: Spacing.xs) {
                if metrics.audioDuration != nil {
                    let text = String(
                        format: L10n("Transcreveu %@ de áudio em %@"),
                        metrics.audioDuration.audioDurationText,
                        metrics.humanReadableTotal
                    )
                    Text(text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(item.statusTitle) · \(metrics.humanReadableTotal)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Button {
                    showingDetails.toggle()
                } label: {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .popover(isPresented: $showingDetails, arrowEdge: .bottom) {
                    BatchItemDetailsPopover(item: item, metrics: metrics)
                }
            }
        } else {
            if let startedAt = item.startedAt, !item.status.isTerminal {
                TimelineView(.periodic(from: startedAt, by: 0.1)) { context -> Text in
                    let elapsed = context.date.timeIntervalSince(startedAt)
                    let formatted = BatchExecutionMetrics.formatDuration(elapsed)
                    Text("\(item.statusTitle) · \(formatted)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        // Uses tabular numbers so the timer string doesn't jitter the UI layout
                        .monospacedDigit()
                }
            } else {
                Text(item.statusTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var defaultDisplayName: String {
        item.inputURL.deletingPathExtension().lastPathComponent
    }

    private var customNameBinding: Binding<String> {
        Binding(
            get: { item.customName ?? defaultDisplayName },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                $item.wrappedValue.customName = trimmed.isEmpty || trimmed == defaultDisplayName ? nil : trimmed
            }
        )
    }

}
