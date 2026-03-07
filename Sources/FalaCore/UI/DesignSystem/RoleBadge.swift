import SwiftUI

public struct RoleBadge: View {
    public let title: String
    public let color: Color
    
    public init(title: String, color: Color) {
        self.title = title
        self.color = color
    }
    
    public var body: some View {
        Text(title)
            .font(Typography.caption2)
            .foregroundColor(FalaColors.textPrimary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xxs)
            .background(color)
            .clipShape(Capsule())
    }
    
    public static var dictation: RoleBadge {
        RoleBadge(title: L10n("Ditado"), color: FalaColors.badgeDictation)
    }

    public static var batch: RoleBadge {
        RoleBadge(title: L10n("Batch"), color: FalaColors.badgeBatch)
    }
}
