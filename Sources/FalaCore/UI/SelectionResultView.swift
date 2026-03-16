import SwiftUI

/// Read-only panel showing the LLM result before pasting.
///
/// Matches the command input panel design — dark material, white stroke,
/// design system tokens throughout.
struct SelectionResultView: View {
    let result: String
    let onPaste: () -> Void
    let onDismiss: () -> Void

    private let shape = RoundedRectangle(
        cornerRadius: CornerRadius.xl, style: .continuous
    )

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            resultContent
            actionBar
        }
        .padding(Spacing.lg)
        .frame(width: 400)
        .background { materialBackground }
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(
                Color.white.opacity(0.12), lineWidth: 0.8
            )
        }
        .shadow(
            color: Color.black.opacity(0.22),
            radius: 24, x: 0, y: 14
        )
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Subviews

    private var resultContent: some View {
        ScrollView {
            Text(result)
                .font(Typography.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 200)
    }

    private var actionBar: some View {
        HStack {
            Button {
                onDismiss()
            } label: {
                Text(L10n("Cancelar"))
                    .font(Typography.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()

            Button {
                onPaste()
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 11, weight: .medium))
                    Text(L10n("Colar"))
                        .font(Typography.body)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .keyboardShortcut(.return, modifiers: [])
        }
    }

    // MARK: - Background

    private var materialBackground: some View {
        ZStack {
            shape.fill(.ultraThinMaterial)
            shape.fill(Color.black.opacity(0.16))
            shape.fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.15),
                        Color.white.opacity(0.03),
                        Color.black.opacity(0.08)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .blendMode(.screen)
        }
    }
}
