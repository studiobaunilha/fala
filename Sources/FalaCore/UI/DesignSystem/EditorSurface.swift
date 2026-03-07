import SwiftUI

public struct EditorSurface<Content: View>: View {
    public let minHeight: CGFloat?
    public let backgroundOpacity: Double

    private let content: Content

    public init(
        minHeight: CGFloat? = nil,
        backgroundOpacity: Double = 1,
        @ViewBuilder content: () -> Content
    ) {
        self.minHeight = minHeight
        self.backgroundOpacity = backgroundOpacity
        self.content = content()
    }

    public var body: some View {
        content
            .frame(minHeight: minHeight)
            .padding(Spacing.xs)
            .background(Color(nsColor: .textBackgroundColor).opacity(backgroundOpacity))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .stroke(Color(nsColor: .separatorColor))
            )
    }
}
