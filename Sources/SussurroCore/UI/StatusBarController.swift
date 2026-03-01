import AppKit
import ApplicationServices

public enum AppState {
    case idle
    case loading
    case recording
    case transcribing
}

@MainActor
public final class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let menu = NSMenu()

    // Items inserted/removed dynamically in menuWillOpen.
    private let axItem: NSMenuItem
    private let axSeparator = NSMenuItem.separator()
    private let settingsItem: NSMenuItem

    private var onSettings: (() -> Void)?
    private var onTranscribe: (() -> Void)?

    public init(
        onSettings: @escaping () -> Void,
        onTranscribe: @escaping () -> Void
    ) {
        self.onSettings = onSettings
        self.onTranscribe = onTranscribe

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        let title = NSMenuItem(title: "Sussurro", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)          // 0
        menu.addItem(.separator())   // 1

        let shortcutItem = NSMenuItem(
            title: "Shortcut: ⌥Space (hold to record)",
            action: nil,
            keyEquivalent: ""
        )
        shortcutItem.isEnabled = false
        menu.addItem(shortcutItem)   // 2
        menu.addItem(.separator())   // 3

        let transcribeItem = NSMenuItem(
            title: "Transcrever Arquivo…",
            action: #selector(StatusBarController.showTranscribe),
            keyEquivalent: "o"
        )
        menu.addItem(transcribeItem) // 4

        settingsItem = NSMenuItem(
            title: "Ajustes…",
            action: #selector(StatusBarController.showSettings),
            keyEquivalent: ","
        )
        menu.addItem(settingsItem)   // 5

        menu.addItem(.separator())   // 6

        axItem = NSMenuItem(
            title: "⚠️ Habilitar Acessibilidade…",
            action: #selector(StatusBarController.openAccessibilitySettings),
            keyEquivalent: ""
        )

        let quitItem = NSMenuItem(
            title: "Sair do Sussurro",
            action: #selector(StatusBarController.quit),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)       // 7

        super.init()

        transcribeItem.target = self
        settingsItem.target = self
        axItem.target = self
        quitItem.target = self
        menu.delegate = self
        statusItem.menu = menu

        setState(.idle)
    }

    // Re-evaluate Accessibility trust every time the menu opens.
    public func menuWillOpen(_ menu: NSMenu) {
        let axPresent = menu.item(withTitle: axItem.title) != nil
        if AXIsProcessTrusted() {
            if axPresent {
                menu.removeItem(axItem)
                menu.removeItem(axSeparator)
            }
        } else if !axPresent {
            let quitIdx = menu.numberOfItems - 1
            menu.insertItem(axSeparator, at: quitIdx)
            menu.insertItem(axItem, at: quitIdx)
        }
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

    @objc private func showSettings() {
        onSettings?()
    }

    @objc private func showTranscribe() {
        onTranscribe?()
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
