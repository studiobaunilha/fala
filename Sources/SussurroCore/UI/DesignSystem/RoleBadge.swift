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
            .foregroundColor(SussurroColors.textPrimary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xxs)
            .background(color)
            .clipShape(Capsule())
    }
    
    public static let dictation = RoleBadge(title: "Ditado", color: SussurroColors.badgeDictation)
    public static let batch = RoleBadge(title: "Batch", color: SussurroColors.badgeBatch)
}
