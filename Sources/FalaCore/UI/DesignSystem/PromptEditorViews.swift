import SwiftUI

public struct PromptEditorPanel<Supplementary: View>: View {
    @Binding private var text: String

    private let placeholder: String?
    private let minHeight: CGFloat
    private let isDisabled: Bool
    private let isModified: Bool
    private let restoreActionTitle: String?
    private let onRestore: (() -> Void)?
    private let supplementary: Supplementary

    public init(
        text: Binding<String>,
        placeholder: String? = nil,
        minHeight: CGFloat = LayoutMetric.promptEditorMinHeight,
        isDisabled: Bool = false,
        isModified: Bool = false,
        restoreActionTitle: String? = nil,
        onRestore: (() -> Void)? = nil,
        @ViewBuilder supplementary: () -> Supplementary
    ) {
        self._text = text
        self.placeholder = placeholder
        self.minHeight = minHeight
        self.isDisabled = isDisabled
        self.isModified = isModified
        self.restoreActionTitle = restoreActionTitle
        self.onRestore = onRestore
        self.supplementary = supplementary()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            EditorSurface(minHeight: minHeight) {
                TextEditor(text: $text)
                    .font(Typography.mono)
                    .scrollContentBackground(.hidden)
                    .disabled(isDisabled)
                    .overlay(alignment: .topLeading) {
                        if let placeholder, text.isEmpty {
                            Text(placeholder)
                                .foregroundStyle(.tertiary)
                                .font(Typography.mono)
                                .padding(.horizontal, Spacing.sm)
                                .padding(.vertical, Spacing.md)
                                .allowsHitTesting(false)
                        }
                    }
            }

            if showsStatusRow {
                HStack {
                    if let restoreActionTitle, let onRestore {
                        Button(restoreActionTitle, action: onRestore)
                            .disabled(!isModified || isDisabled)
                    }

                    Spacer()

                    if isModified {
                        Label(L10n("Modificado"), systemImage: "pencil.circle.fill")
                            .font(.caption)
                            .foregroundStyle(FalaColors.warning)
                    }
                }
            }

            supplementary
        }
    }

    private var showsStatusRow: Bool {
        restoreActionTitle != nil || isModified
    }
}

public extension PromptEditorPanel where Supplementary == EmptyView {
    init(
        text: Binding<String>,
        placeholder: String? = nil,
        minHeight: CGFloat = LayoutMetric.promptEditorMinHeight,
        isDisabled: Bool = false,
        isModified: Bool = false,
        restoreActionTitle: String? = nil,
        onRestore: (() -> Void)? = nil
    ) {
        self.init(
            text: text,
            placeholder: placeholder,
            minHeight: minHeight,
            isDisabled: isDisabled,
            isModified: isModified,
            restoreActionTitle: restoreActionTitle,
            onRestore: onRestore,
            supplementary: { EmptyView() }
        )
    }
}

public struct PromptEditorNote: View {
    private let message: String
    private let systemImage: String
    private let tint: Color

    public init(
        message: String,
        systemImage: String = "info.circle",
        tint: Color = FalaColors.info
    ) {
        self.message = message
        self.systemImage = systemImage
        self.tint = tint
    }

    public var body: some View {
        Label {
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .font(.caption)
        }
    }
}
