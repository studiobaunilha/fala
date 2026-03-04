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
        model.isVisible = true
        panel?.orderFront(nil) // NOT makeKeyAndOrderFront — no focus steal
    }

    public func dismiss() {
        model.stage = .done
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            self.panel?.orderOut(nil)
            self.model.isVisible = false
        }
    }

    private func makePanel() {
        let feedbackView = DictationFeedbackView(model: model)
        let hostingView = NSHostingView(rootView: feedbackView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        let panelRect = NSRect(x: 0, y: 0, width: 280, height: 140)
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
        newPanel.hasShadow = true
        newPanel.isReleasedWhenClosed = false

        // Vibrancy background — matches macOS HUD appearance
        let visualEffect = NSVisualEffectView(frame: panelRect)
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 20
        visualEffect.layer?.masksToBounds = true

        visualEffect.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: visualEffect.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor)
        ])

        newPanel.contentView = visualEffect

        // Position: center-bottom of screen, above dock
        if let screen = NSScreen.main {
            let visibleFrame = screen.visibleFrame
            let originX = visibleFrame.midX - panelRect.width / 2
            let originY = visibleFrame.minY + 80
            newPanel.setFrameOrigin(NSPoint(x: originX, y: originY))
        }

        panel = newPanel
    }
}
