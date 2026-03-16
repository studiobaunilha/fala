import SwiftUI

/// Floating text input for the Selection + AI Command "quick tap" flow.
///
/// Matches the HUD pill aesthetic: dark material backdrop with subtle
/// gradients, white stroke, and `.continuous` rounded corners.
struct SelectionCommandView: View {
    let selectionPreview: String
    let onSubmit: (String) -> Void
    let onDismiss: () -> Void

    @State private var command = ""
    @FocusState private var isFocused: Bool

    private let shape = RoundedRectangle(
        cornerRadius: CornerRadius.xl, style: .continuous
    )

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            selectionBadge
            commandField
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.lg)
        .frame(width: 320)
        .background { materialBackground }
        .clipShape(shape)
        .overlay { shape.strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8) }
        .shadow(color: Color.black.opacity(0.22), radius: 24, x: 0, y: 14)
        .onAppear { isFocused = true }
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Subviews

    private var selectionBadge: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "text.quote")
                .font(.system(size: 9, weight: .medium))
            Text(selectionPreview)
                .font(Typography.caption)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .foregroundStyle(.secondary)
    }

    private var commandField: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            TextField(
                "O que fazer com o texto?",
                text: $command
            )
            .textFieldStyle(.plain)
            .font(Typography.body)
            .focused($isFocused)
            .onSubmit {
                let trimmed = command.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                guard !trimmed.isEmpty else { return }
                onSubmit(command)
            }

            if !command.isEmpty {
                Text("↩")
                    .font(Typography.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Background (matching DictationFeedbackView)

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
