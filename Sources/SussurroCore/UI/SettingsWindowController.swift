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
            title: "Ajustes",
            width: WindowSize.settingsWidth,
            height: WindowSize.settingsHeight,
            isResizable: true, // Crucial for NavigationSplitView
            minSize: NSSize(width: 600, height: 400),
            maxSize: NSSize(width: WindowSize.settingsMaxWidth, height: WindowSize.settingsMaxHeight),
            fullSizeContentView: true,
            transparentTitlebar: true
        )
        
        let win = WindowFactory.makeWindow(config: config, content: SettingsView(
            settings: settings,
            modelManager: settings.modelManager
        ))
        
        self.window = win
        NSLog("[Sussurro] makeWindow() — activating app and showing window")
        WindowFactory.show(win)
        NSLog("[Sussurro] makeWindow() — done, isVisible=%d", win.isVisible ? 1 : 0)
    }
}
