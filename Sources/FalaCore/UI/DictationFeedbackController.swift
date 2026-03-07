import AppKit
import SwiftUI

/// Manages the floating NSPanel that displays real-time dictation feedback.
/// Uses `.nonactivatingPanel` so it never steals focus from the user's active app.
@MainActor
public final class DictationFeedbackController {
    private var panel: NSPanel?
    public let model = DictationFeedbackModel()

    public init() {}

    public func show() {
        if panel == nil { makePanel() }
        model.startDisplayUpdates()
        model.isVisible = true
        panel?.orderFront(nil) // NOT makeKeyAndOrderFront — no focus steal
    }

    public func dismiss() {
        model.stage = .done
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            self.model.stopDisplayUpdates()
            self.panel?.orderOut(nil)
            self.model.isVisible = false
        }
    }

    private func makePanel() {
        let feedbackView = DictationFeedbackView(model: model)

        let hostingView = NSHostingView(rootView: feedbackView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor

        let containerView = makeTransparentContainer(hostingView: hostingView)

        let panelRect = NSRect(
            x: 0,
            y: 0,
            width: DictationFeedbackLayout.width,
            height: DictationFeedbackLayout.height
        )
        let newPanel = NSPanel(
            contentRect: panelRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        newPanel.level = .floating
        newPanel.isMovableByWindowBackground = true
        newPanel.hidesOnDeactivate = false
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.backgroundColor = .clear
        newPanel.isOpaque = false
        newPanel.hasShadow = false
        newPanel.isReleasedWhenClosed = false

        newPanel.contentView = containerView
        newPanel.contentView?.wantsLayer = true
        newPanel.contentView?.layer?.backgroundColor = NSColor.clear.cgColor

        // Position: center-bottom of screen, above dock
        if let screen = NSScreen.main {
            let visibleFrame = screen.visibleFrame
            let originX = visibleFrame.midX - panelRect.width / 2
            let originY = visibleFrame.minY + 80
            newPanel.setFrameOrigin(NSPoint(x: originX, y: originY))
        }

        panel = newPanel
    }

    private func makeTransparentContainer(hostingView: NSHostingView<DictationFeedbackView>) -> NSView {
        let containerView = NSView(frame: NSRect(
            x: 0,
            y: 0,
            width: DictationFeedbackLayout.width,
            height: DictationFeedbackLayout.height
        ))
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.clear.cgColor
        containerView.addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: containerView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        return containerView
    }
}
