import AppKit
import SwiftUI

/// Creates and manages the floating settings window.
/// The window is instantiated lazily on first `show()` call and reused afterwards.
@MainActor
public final class SettingsWindowController {
    private var window: NSWindow?
    private let settings: AppSettings
    private let navigationState = SettingsNavigationState()

    public init(settings: AppSettings) {
        self.settings = settings
        self.settings.openSettingsSelection = { [weak self] selection in
            self?.show(selection: selection)
        }
    }

    var currentWindow: NSWindow? {
        window
    }

    public func show() {
        NSLog("[Fala] show() — window already exists: %d", window != nil ? 1 : 0)
        if let window {
            reloadLocalizedContent()
            WindowFactory.show(window)
            return
        }
        makeWindow()
    }

    public func show(selection: SettingsSelection) {
        navigationState.selection = selection
        show()
    }

    public func reloadLocalizedContent() {
        guard let window else { return }
        WindowFactory.applyContent(
            SettingsView(
                settings: settings,
                modelManager: settings.modelManager,
                navigationState: navigationState
            ),
            config: windowConfig,
            to: window
        )
    }

    private func makeWindow() {
        NSLog("[Fala] makeWindow() — creating SettingsView")
        let config = windowConfig
        
        let win = WindowFactory.makeWindow(config: config, content: SettingsView(
            settings: settings,
            modelManager: settings.modelManager,
            navigationState: navigationState
        ))

        // HIG: Settings windows show traffic lights but dim minimize/zoom
        win.standardWindowButton(.miniaturizeButton)?.isEnabled = false
        win.standardWindowButton(.zoomButton)?.isEnabled = false

        self.window = win
        NSLog("[Fala] makeWindow() — activating app and showing window")
        WindowFactory.show(win)
        NSLog("[Fala] makeWindow() — done, isVisible=%d", win.isVisible ? 1 : 0)
    }

    private var windowConfig: WindowConfig {
        WindowConfig(
            title: L10n("Ajustes"),
            width: WindowSize.settingsDefaultWidth,
            height: WindowSize.settingsDefaultHeight,
            styleMask: [.titled, .closable, .miniaturizable],
            isResizable: true,
            minSize: NSSize(width: WindowSize.settingsMinWidth, height: WindowSize.settingsMinHeight),
            maxSize: NSSize(width: WindowSize.settingsMaxWidth, height: WindowSize.settingsMaxHeight),
            fullSizeContentView: true,
            transparentTitlebar: true
        )
    }
}
