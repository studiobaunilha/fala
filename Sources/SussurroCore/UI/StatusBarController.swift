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
    
    private let settings: AppSettings

    private var onSettings: (() -> Void)?
    private var onTranscribe: (() -> Void)?
    
    private var modeItems: [NSMenuItem] = []

    public init(
        settings: AppSettings,
        onSettings: @escaping () -> Void,
        onTranscribe: @escaping () -> Void
    ) {
        self.settings = settings
        self.onSettings = onSettings
        self.onTranscribe = onTranscribe

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        let title = NSMenuItem(title: "Sussurro", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())

        let shortcutItem = NSMenuItem(
            title: "Atalho: ⌥Espaço (segure para gravar)",
            action: nil,
            keyEquivalent: ""
        )
        shortcutItem.isEnabled = false
        menu.addItem(shortcutItem)
        menu.addItem(.separator())

        let transcribeItem = NSMenuItem(
            title: "Transcrever Arquivo…",
            action: #selector(StatusBarController.showTranscribe),
            keyEquivalent: "o"
        )

        settingsItem = NSMenuItem(
            title: "Ajustes…",
            action: #selector(StatusBarController.showSettings),
            keyEquivalent: ","
        )

        axItem = NSMenuItem(
            title: "⚠️ Habilitar Acessibilidade…",
            action: #selector(StatusBarController.openAccessibilitySettings),
            keyEquivalent: ""
        )

        super.init()

        buildModeItems()

        menu.addItem(transcribeItem)
        menu.addItem(settingsItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Sair do Sussurro",
            action: #selector(StatusBarController.quit),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        transcribeItem.target = self
        settingsItem.target = self
        axItem.target = self
        quitItem.target = self
        
        menu.delegate = self
        statusItem.menu = menu

        setState(.idle)
    }

    private func buildModeItems() {
        let modeHeader = NSMenuItem(title: "Modo de Captura:", action: nil, keyEquivalent: "")
        modeHeader.isEnabled = false
        menu.addItem(modeHeader)
        
        for mode in DictationTemplate.allCases {
            let item = NSMenuItem(
                title: mode.rawValue,
                action: #selector(StatusBarController.selectMode(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = mode.rawValue
            modeItems.append(item)
            menu.addItem(item)
        }
        
        menu.addItem(.separator())
    }

    // Re-evaluate Accessibility trust and Mode selection every time the menu opens.
    public func menuWillOpen(_ menu: NSMenu) {
        // Update Checkmarks for Modes
        let currentMode = settings.selectedDictationTemplate
        for item in modeItems {
            if let modeRaw = item.representedObject as? String, modeRaw == currentMode.rawValue {
                item.state = .on
            } else {
                item.state = .off
            }
        }
        
        // Accessibility check
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
    
    @objc private func selectMode(_ sender: NSMenuItem) {
        if let modeRaw = sender.representedObject as? String,
           let mode = DictationTemplate(rawValue: modeRaw) {
            settings.selectedDictationTemplate = mode
            settings.save()
        }
    }

    public func setState(_ state: AppState) {
        let (name, description): (String, String) = switch state {
        case .idle: ("mic", "Sussurro — pronto")
        case .loading: ("arrow.down.circle", "Sussurro — carregando modelo…")
        case .recording: ("mic.fill", "Sussurro — gravando")
        case .transcribing: ("waveform", "Sussurro — transcrevendo…")
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
