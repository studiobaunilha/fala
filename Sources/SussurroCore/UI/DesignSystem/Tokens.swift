import SwiftUI

public enum SussurroColors {
    // Semânticas (paleta escura inspirada no Raycast)
    public static let accent = Color(red: 0.35, green: 0.55, blue: 1.0)
    public static let success = Color(red: 0.30, green: 0.78, blue: 0.47)
    public static let warning = Color(red: 1.0, green: 0.72, blue: 0.25)
    public static let error = Color(red: 1.0, green: 0.35, blue: 0.37)
    public static let purple = Color(red: 0.65, green: 0.45, blue: 0.95)

    // Texto
    public static let textPrimary = Color.white.opacity(0.95)
    public static let textSecondary = Color.white.opacity(0.55)

    // Superfícies
    public static let surfacePrimary = Color.white.opacity(0.06)
    public static let surfaceSecondary = Color.white.opacity(0.04)
    public static let border = Color.white.opacity(0.10)

    // Badges
    public static let badgeDictation = accent.opacity(0.15)
    public static let badgeBatch = warning.opacity(0.15)
}

public enum Spacing {
    public static let xxs: CGFloat = 2
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 6
    public static let md: CGFloat = 8
    public static let lg: CGFloat = 12
    public static let xl: CGFloat = 16
    public static let xxl: CGFloat = 24
}

public enum CornerRadius {
    public static let sm: CGFloat = 4
    public static let md: CGFloat = 8
    public static let lg: CGFloat = 12
}

public enum Typography {
    public static let title = Font.system(size: 16, weight: .semibold)
    public static let headline = Font.system(size: 14, weight: .medium)
    public static let body = Font.system(size: 13)
    public static let caption = Font.system(size: 11)
    public static let caption2 = Font.system(size: 10, weight: .medium)
    public static let mono = Font.system(size: 11, design: .monospaced)
}

public enum WindowSize {
    public static let settingsDefaultHeight: CGFloat = 600
    public static let settingsMinHeight: CGFloat = 600
    public static let settingsMaxHeight: CGFloat = 1000

    public static let settingsDefaultWidth: CGFloat = 700
    public static let settingsMinWidth: CGFloat = 700
    public static let settingsMaxWidth: CGFloat = 1000

    public static let transcribeDefaultHeight: CGFloat = 600
    public static let transcribeMinHeight: CGFloat = 600
    public static let transcribeMaxHeight: CGFloat = 1000

    public static let transcribeDefaultWidth: CGFloat = 700
    public static let transcribeMinWidth: CGFloat = 700
    public static let transcribeMaxWidth: CGFloat = 1000
}
