import AppKit

enum InsertionReviewPlacement {
    static let collapsedSize = NSSize(width: 280, height: 54)
    static let expandedSize = NSSize(width: 360, height: 220)
    static let trailingInset: CGFloat = 24
    static let bottomInset: CGFloat = 24

    static func origin(for size: NSSize, visibleFrame: NSRect) -> NSPoint {
        NSPoint(
            x: visibleFrame.maxX - size.width - trailingInset,
            y: visibleFrame.minY + bottomInset
        )
    }

    static func screen(containing point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
            ?? NSScreen.main
    }
}
