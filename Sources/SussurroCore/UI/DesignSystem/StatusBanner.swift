import SwiftUI

public struct StatusBanner: View {
    public let message: String
    
    public init(message: String) {
        self.message = message
    }
    
    public var body: some View {
        HStack(spacing: Spacing.lg) {
            ProgressView()
                .controlSize(.small)
            Text(message)
                .font(Typography.body)
                .foregroundColor(SussurroColors.textPrimary)
        }
        .padding(Spacing.lg)
        .background(SussurroColors.surfacePrimary)
        .cornerRadius(CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .stroke(SussurroColors.border, lineWidth: 1)
        )
    }
}
