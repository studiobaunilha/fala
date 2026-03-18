import AppKit
import SwiftUI

/// Manages the floating window that prompts the user to save a learned correction.
@MainActor
public final class CorrectionLearningController {
    public static let shared = CorrectionLearningController()

    private var panel: NSPanel?
    private var onSaveContext: (() -> Void)?
    private var dismissWorkItem: DispatchWorkItem?

    private init() {}

    /// Shows the learning prompt near the current mouse cursor.
    public func promptForCorrection(original: String, corrected: String, onSave: @escaping () -> Void) {
        dismiss()
        self.onSaveContext = onSave

        let panel = createPanel()
        let view = CorrectionLearningView(
            originalWord: original,
            correctedWord: corrected,
            onSave: { [weak self] in
                self?.onSaveContext?()
                self?.dismiss()
            },
            onDismiss: { [weak self] in
                self?.dismiss()
            }
        )

        panel.contentView = NSHostingView(rootView: view)
        let origin = positionPanel(
            size: panel.frame.size,
            near: NSEvent.mouseLocation
        )
        panel.setFrameOrigin(origin)
        self.panel = panel

        // Show panel without stealing focus from the active app (where user is typing!)
        panel.orderFrontRegardless()

        // As a safeguard, auto-dismiss after 6.5s in case the SwiftUI timer fails
        let item = DispatchWorkItem { [weak self] in
            self?.dismiss()
        }
        self.dismissWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.5, execute: item)
    }

    public func dismiss() {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil

        panel?.orderOut(nil)
        panel = nil
        onSaveContext = nil
    }

    private func createPanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 160),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: NSWindow.BackingStoreType.buffered,
            defer: false
        )
        panel.level = NSWindow.Level.floating
        panel.hidesOnDeactivate = false
        panel.backgroundColor = NSColor.clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = NSWindow.CollectionBehavior(
            [.canJoinAllSpaces, .fullScreenAuxiliary]
        )
        return panel
    }

    private func positionPanel(size: NSSize, near point: NSPoint) -> NSPoint {
        var origin = NSPoint(
            x: point.x - size.width / 2,
            y: point.y - 120
        )
        if let vis = NSScreen.main?.visibleFrame {
            origin.x = max(
                vis.minX + 8,
                min(origin.x, vis.maxX - size.width - 8)
            )
            origin.y = max(
                vis.minY + 8,
                min(origin.y, vis.maxY - size.height - 8)
            )
        }
        return origin
    }
}
