import SwiftUI

struct InsertionReviewView: View {
    let insertedText: String
    let onUndo: () -> Void
    let onApplyEdit: (String) -> Void
    let onDismiss: () -> Void
    let onHoverChanged: (Bool) -> Void
    let onEditingChanged: (Bool) -> Void

    @State private var isHovered = false
    @State private var isEditing = false
    @State private var draftText: String
    @FocusState private var editorFocused: Bool

    private let shape = RoundedRectangle(
        cornerRadius: CornerRadius.xl,
        style: .continuous
    )

    init(
        insertedText: String,
        onUndo: @escaping () -> Void,
        onApplyEdit: @escaping (String) -> Void,
        onDismiss: @escaping () -> Void,
        onHoverChanged: @escaping (Bool) -> Void,
        onEditingChanged: @escaping (Bool) -> Void
    ) {
        self.insertedText = insertedText
        self.onUndo = onUndo
        self.onApplyEdit = onApplyEdit
        self.onDismiss = onDismiss
        self.onHoverChanged = onHoverChanged
        self.onEditingChanged = onEditingChanged
        _draftText = State(initialValue: insertedText)
    }

    var body: some View {
        Group {
            if isEditing {
                editorContent
            } else {
                bubbleContent
            }
        }
        .padding(isEditing ? Spacing.lg : Spacing.md)
        .background { materialBackground }
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(
                Color.primary.opacity(0.10),
                lineWidth: 0.8
            )
        }
        .shadow(
            color: Color.black.opacity(0.10),
            radius: 18,
            x: 0,
            y: 10
        )
        .onHover { hovering in
            isHovered = hovering
            onHoverChanged(hovering)
        }
        .onChange(of: isEditing) { _, newValue in
            onEditingChanged(newValue)
            if newValue {
                Task { @MainActor in
                    editorFocused = true
                }
            }
        }
    }

    private var bubbleContent: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "text.badge.star")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Text(insertedText)
                .font(Typography.body)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: Spacing.xs) {
                actionButton(title: L10n("Editar")) {
                    isEditing = true
                }

                actionButton(title: L10n("Desfazer")) {
                    onUndo()
                }
            }
            .opacity(isHovered ? 1 : 0)
            .allowsHitTesting(isHovered)

            dismissButton
                .opacity(isHovered ? 1 : 0)
                .allowsHitTesting(isHovered)
        }
        .animation(.easeOut(duration: 0.14), value: isHovered)
    }

    private var editorContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            TextEditor(text: $draftText)
                .font(Typography.body)
                .scrollContentBackground(.hidden)
                .padding(Spacing.sm)
                .frame(minHeight: 130)
                .background(
                    RoundedRectangle(
                        cornerRadius: CornerRadius.md,
                        style: .continuous
                    )
                    .fill(Color.primary.opacity(0.05))
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: CornerRadius.md,
                        style: .continuous
                    )
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8)
                }
                .focused($editorFocused)

            HStack {
                Button(L10n("Cancelar")) {
                    draftText = insertedText
                    isEditing = false
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Spacer()

                Button(L10n("OK")) {
                    onApplyEdit(draftText)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(
                    draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
        }
    }

    private var dismissButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.plain)
    }

    private func actionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(Typography.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )
    }

    private var materialBackground: some View {
        ZStack {
            shape.fill(.thinMaterial)
            shape.fill(Color(nsColor: .windowBackgroundColor).opacity(0.82))
        }
    }
}
