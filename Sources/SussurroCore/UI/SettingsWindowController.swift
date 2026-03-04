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
            WindowFactory.show(window)
            return
        }
        makeWindow()
    }

    private func makeWindow() {
        NSLog("[Sussurro] makeWindow() — creating SettingsView")
        let config = WindowConfig(
            title: L10n("Ajustes"),
            width: WindowSize.settingsDefaultWidth,
            height: WindowSize.settingsDefaultHeight,
            styleMask: [.titled, .closable, .miniaturizable],
            isResizable: true, // Crucial for NavigationSplitView
            minSize: NSSize(width: WindowSize.settingsMinWidth, height: WindowSize.settingsMinHeight),
            maxSize: NSSize(width: WindowSize.settingsMaxWidth, height: WindowSize.settingsMaxHeight),
            fullSizeContentView: true,
            transparentTitlebar: true
        )
        
        let win = WindowFactory.makeWindow(config: config, content: SettingsView(
            settings: settings,
            modelManager: settings.modelManager
        ))

        // HIG: Settings windows show traffic lights but dim minimize/zoom
        win.standardWindowButton(.miniaturizeButton)?.isEnabled = false
        win.standardWindowButton(.zoomButton)?.isEnabled = false

        self.window = win
        NSLog("[Sussurro] makeWindow() — activating app and showing window")
        WindowFactory.show(win)
        NSLog("[Sussurro] makeWindow() — done, isVisible=%d", win.isVisible ? 1 : 0)
    }
}
