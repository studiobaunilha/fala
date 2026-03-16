import SwiftUI

/// Panel showing the LLM result with an optional refinement field.
///
/// After the AI processes a command, this panel displays the result
/// and offers a text field for follow-up refinements ("mais formal",
/// "traduz pra inglês", etc.). Auto-dismisses after ~5s unless the
/// user starts typing.
struct SelectionResultView: View {
    let result: String
    let onPaste: () -> Void
    let onRefine: ((String) -> Void)?
    let onDismiss: () -> Void

    @State private var refinement = ""
    @State private var timerProgress: CGFloat = 1.0
    @FocusState private var isFocused: Bool

    /// Seconds before auto-dismiss, or `nil` to stay open.
    let timeout: Double?

    private let shape = RoundedRectangle(
        cornerRadius: CornerRadius.xl, style: .continuous
    )

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            resultContent
            if onRefine != nil { refinementField }
            actionBar
            if onRefine != nil, timeout != nil { timerBar }
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
        .task { await runTimer() }
    }

    // MARK: - Timer

    private func runTimer() async {
        guard onRefine != nil, let limit = timeout else { return }
        let steps = 50
        let interval = limit / Double(steps)
        for _ in 0..<steps {
            try? await Task.sleep(
                nanoseconds: UInt64(interval * 1_000_000_000)
            )
            if !refinement.isEmpty { return }
            timerProgress -= 1.0 / CGFloat(steps)
        }
        if refinement.isEmpty { onDismiss() }
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

    private var refinementField: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            TextField(
                L10n("Quer ajustar?"),
                text: $refinement
            )
            .textFieldStyle(.plain)
            .font(Typography.body)
            .focused($isFocused)
            .onSubmit {
                let trimmed = refinement.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                guard !trimmed.isEmpty else { return }
                onRefine?(trimmed)
            }

            if !refinement.isEmpty {
                Text("↩")
                    .font(Typography.caption)
                    .foregroundStyle(.tertiary)
            }
        }
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
            .keyboardShortcut(.return, modifiers: [.command])
        }
    }

    private var timerBar: some View {
        GeometryReader { geo in
            Capsule()
                .fill(Color.white.opacity(0.15))
                .frame(
                    width: geo.size.width * max(timerProgress, 0),
                    height: 2
                )
                .animation(.linear(duration: 0.1), value: timerProgress)
        }
        .frame(height: 2)
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
