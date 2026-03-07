import SwiftUI

public struct SidebarWarningIndicator: View {
    public let helpText: String

    public init(helpText: String) {
        self.helpText = helpText
    }

    public var body: some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(FalaColors.warning)
            .font(Typography.caption)
            .help(helpText)
    }
}
