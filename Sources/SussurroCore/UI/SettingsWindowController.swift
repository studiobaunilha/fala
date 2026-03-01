import AppKit
import SwiftUI

/// Creates and manages the floating settings window.
/// The window is instantiated lazily on first `show()` call and reused afterwards.
@MainActor
public final class SettingsWindowController {
    private var window: NSWindow?
    private let settings: AppSettings

    public init(settings: AppSettings) {
        self.settings = settings
    }

    public func show() {
        NSLog("[Sussurro] show() — window already exists: %d", window != nil ? 1 : 0)
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        makeWindow()
    }

    private func makeWindow() {
        NSLog("[Sussurro] makeWindow() — creating SettingsView")
        let hosting = NSHostingView(rootView: SettingsView(
            settings: settings,
            modelManager: settings.modelManager
        ))
        hosting.sizingOptions = .preferredContentSize

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "Ajustes — Sussurro"
        win.contentView = hosting
        win.center()
        win.isReleasedWhenClosed = false
        self.window = win

        NSLog("[Sussurro] makeWindow() — activating app and showing window")
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
        NSLog("[Sussurro] makeWindow() — done, isVisible=%d", win.isVisible ? 1 : 0)
    }
}
