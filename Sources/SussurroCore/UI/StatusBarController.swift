import AppKit
import ApplicationServices

public enum AppState {
    case idle
    case loading
    case recording
    case transcribing
}

@MainActor
public final class StatusBarController {
    private let statusItem: NSStatusItem

    public init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        setState(.idle)

        let menu = NSMenu()

        let title = NSMenuItem(title: "Sussurro", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())

        let shortcutItem = NSMenuItem(
            title: "Shortcut: ⌥Space (hold to record)",
            action: nil,
            keyEquivalent: ""
        )
        shortcutItem.isEnabled = false
        menu.addItem(shortcutItem)

        menu.addItem(.separator())

        if !AXIsProcessTrusted() {
            let axItem = NSMenuItem(
                title: "⚠️ Habilitar Acessibilidade…",
                action: #selector(openAccessibilitySettings),
                keyEquivalent: ""
            )
            axItem.target = self
            menu.addItem(axItem)
            menu.addItem(.separator())
        }

        let quitItem = NSMenuItem(title: "Quit Sussurro", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    public func setState(_ state: AppState) {
        let (name, description): (String, String) = switch state {
        case .idle: ("mic", "Sussurro — idle")
        case .loading: ("arrow.down.circle", "Sussurro — loading model…")
        case .recording: ("mic.fill", "Sussurro — recording")
        case .transcribing: ("waveform", "Sussurro — transcribing…")
        }
        statusItem.button?.image = NSImage(systemSymbolName: name, accessibilityDescription: description)
    }

    @objc private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
