import SwiftUI

public struct CatalogProgressStatusView: View {
    public let progress: Double

    public init(progress: Double) {
        self.progress = progress
    }

    public var body: some View {
        VStack(alignment: .trailing, spacing: Spacing.xs) {
            ProgressView(value: progress)
                .frame(width: LayoutMetric.compactProgressWidth)
                .controlSize(.small)
            Text("\(Int(progress * 100))%")
                .font(Typography.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}

public struct CatalogPrimaryActionButton: View {
    public let title: String
    public let role: ButtonRole?
    public let isDisabled: Bool
    public let action: () -> Void

    public init(
        title: String,
        role: ButtonRole? = nil,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.role = role
        self.isDisabled = isDisabled
        self.action = action
    }

    public var body: some View {
        Button(title, role: role, action: action)
            .frame(minWidth: LayoutMetric.catalogPrimaryActionMinWidth)
            .disabled(isDisabled)
    }
}

public struct CatalogRemoveButton: View {
    public let helpText: String
    public let action: () -> Void

    public init(
        helpText: String = L10n("Apagar modelo"),
        action: @escaping () -> Void
    ) {
        self.helpText = helpText
        self.action = action
    }

    public var body: some View {
        Button(role: .destructive, action: action) {
            Image(systemName: "trash")
                .frame(
                    width: LayoutMetric.catalogIconButtonSize,
                    height: LayoutMetric.catalogIconButtonSize
                )
        }
        .buttonStyle(.borderless)
        .help(helpText)
    }
}
