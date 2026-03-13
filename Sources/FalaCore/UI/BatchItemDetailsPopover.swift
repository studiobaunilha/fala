import SwiftUI

struct BatchItemDetailsPopover: View {
    let item: BatchQueueItem
    let metrics: BatchExecutionMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(L10n("Detalhes da Transcrição"))
                .font(.headline)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                detailRow(label: L10n("Arquivo"), value: item.inputURL.lastPathComponent)
                detailRow(label: L10n("Tamanho"), value: metrics.inputFileSize.fileSizeText)
                if metrics.audioDuration != nil {
                    detailRow(label: L10n("Duração"), value: metrics.audioDuration.audioDurationText)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(L10n("Tempo de Execução"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ForEach(metrics.stageBreakdown, id: \.label) { stage in
                    HStack {
                        Text(stage.label)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(stage.value)
                            .monospacedDigit()
                    }
                    .font(.callout)
                }

                Divider()

                HStack {
                    Text(L10n("Tempo Total"))
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(metrics.humanReadableTotal)
                        .monospacedDigit()
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                }
                .font(.callout)
            }
        }
        .padding(Spacing.lg)
        .frame(width: 300)
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label + ":")
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.callout)
    }
}
