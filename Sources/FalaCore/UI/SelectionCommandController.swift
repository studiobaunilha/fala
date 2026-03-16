import AppKit
import SwiftUI

/// Manages the floating panel for typed Selection + AI Commands.
///
/// Appears near the user's mouse cursor when they do a "quick tap"
/// of the shortcut with text selected. The panel never steals focus
/// from the active application.

/// Borderless panel that can still receive key events (for the text field).
private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
public final class SelectionCommandController {
    private var panel: NSPanel?
    private var onSubmit: ((String, String) -> Void)?
    private var currentSelection: String?
    private var escapeMonitor: Any?

    public init() {}

    // MARK: - Command Input

    /// Shows the command panel near the given screen point.
    func show(
        selection: String,
        near point: NSPoint,
        onSubmit handler: @escaping (String, String) -> Void
    ) {
        dismiss()
        currentSelection = selection
        onSubmit = handler

        let preview = String(selection.prefix(60))
            + (selection.count > 60 ? "…" : "")

        let view = SelectionCommandView(
            selectionPreview: preview,
            onSubmit: { [weak self] command in
                guard let self,
                      let sel = self.currentSelection else { return }
                self.onSubmit?(command, sel)
                self.dismiss()
            },
            onDismiss: { [weak self] in self?.dismiss() }
        )
        presentPanel(
            content: view,
            size: NSSize(width: 360, height: 100),
            near: point
        )
    }

    // MARK: - Result Preview

    /// Shows the result panel near the mouse cursor.
    func showResult(
        text: String,
        near point: NSPoint,
        timeout: Double? = nil,
        onRefine: ((String) -> Void)? = nil,
        onPaste: @escaping () -> Void
    ) {
        dismiss()
        let view = SelectionResultView(
            result: text,
            onPaste: { [weak self] in
                onPaste()
                self?.dismiss()
            },
            onRefine: onRefine.map { handler in
                { [weak self] command in
                    self?.dismiss()
                    handler(command)
                }
            },
            onDismiss: { [weak self] in self?.dismiss() },
            timeout: timeout
        )
        presentPanel(
            content: view,
            size: NSSize(width: 400, height: 300),
            near: point
        )
    }

    // MARK: - Dismiss

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
        currentSelection = nil
        onSubmit = nil
        if let monitor = escapeMonitor {
            NSEvent.removeMonitor(monitor)
            escapeMonitor = nil
        }
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    // MARK: - Shared Panel Factory

    private func presentPanel<V: View>(
        content: V,
        size: NSSize,
        near point: NSPoint
    ) {
        let hosting = NSHostingView(rootView: content)
        hosting.autoresizingMask = [.width, .height]

        let rect = NSRect(origin: .zero, size: size)
        let container = NSView(frame: rect)
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor
        container.addSubview(hosting)
        hosting.frame = container.bounds

        let newPanel = KeyablePanel(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        newPanel.level = .floating
        // Must be false — Fala runs as .accessory (no dock icon), so
        // the app is never "active" and the panel would hide immediately.
        newPanel.hidesOnDeactivate = false
        newPanel.collectionBehavior = [
            .canJoinAllSpaces, .fullScreenAuxiliary
        ]
        newPanel.backgroundColor = .clear
        newPanel.isOpaque = false
        newPanel.hasShadow = false
        newPanel.isReleasedWhenClosed = false
        newPanel.contentView = container

        let origin = positionPanel(
            size: newPanel.frame.size, near: point
        )
        newPanel.setFrameOrigin(origin)
        newPanel.makeKeyAndOrderFront(nil)
        panel = newPanel

        escapeMonitor = NSEvent.addLocalMonitorForEvents(
            matching: .keyDown
        ) { [weak self] event in
            if event.keyCode == 53 {
                self?.dismiss()
                return nil
            }
            return event
        }
    }

    // MARK: - Positioning

    private func positionPanel(
        size: NSSize, near point: NSPoint
    ) -> NSPoint {
        var origin = NSPoint(
            x: point.x - size.width / 2,
            y: point.y - 40
        )
        if let vis = NSScreen.main?.visibleFrame {
            origin.x = max(vis.minX + 8, min(
                origin.x, vis.maxX - size.width - 8
            ))
            origin.y = max(vis.minY + 8, min(
                origin.y, vis.maxY - size.height - 8
            ))
        }
        return origin
    }
}
