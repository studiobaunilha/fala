import SwiftUI

struct InsertionCorrectionProposalView: View {
    let correction: CorrectionLearningAnalyzer.LearnedCorrection
    let onApprove: () -> Void
    let onReject: () -> Void
    let onHoverChanged: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text(L10n("Regra global de substituição"))
                    .font(.headline)
                Spacer()
                Button(action: onReject) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n("Fechar proposta"))
            }

            Text(L10n("Aprovar salva esta substituição para textos futuros em todos os contextos."))
                .font(Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    pairValue(correction.original, label: L10n("Texto original"))
                    pairValue(correction.corrected, label: L10n("Substituição proposta"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Button(L10n("Rejeitar"), action: onReject)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(L10n("Aprovar"), action: onApprove)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(Spacing.lg)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
        .onHover(perform: onHoverChanged)
    }

    private func pairValue(_ value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(.secondary)
            Text(verbatim: value)
                .font(Typography.body)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
