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
    private var currentState: AppState = .idle

    var settingsItemTitleForTesting: String {
        settingsItem.title
    }

    public init(
        settings: AppSettings,
        onSettings: @escaping () -> Void,
        onTranscribe: @escaping () -> Void
    ) {
        self.settings = settings
        self.onSettings = onSettings
        self.onTranscribe = onTranscribe

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        settingsItem = Self.makeSettingsItem()
        axItem = Self.makeAccessibilityItem()

        super.init()

        axItem.target = self

        rebuildMenu()

        setState(.idle)
    }

    private static func makeSettingsItem() -> NSMenuItem {
        NSMenuItem(
            title: L10n("Ajustes…"),
            action: #selector(StatusBarController.showSettings),
            keyEquivalent: ","
        )
    }

    private static func makeAccessibilityItem() -> NSMenuItem {
        let item = NSMenuItem(
            title: L10n("Habilitar Acessibilidade…"),
            action: #selector(StatusBarController.openAccessibilitySettings),
            keyEquivalent: ""
        )
        item.image = NSImage(
            systemSymbolName: "exclamationmark.triangle.fill",
            accessibilityDescription: L10n("Alerta")
        )
        item.image?.isTemplate = false
        return item
    }

    private func buildStaticMenuItems() {
        let title = NSMenuItem(title: L10n("Fala"), action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())

        let shortcutItem = NSMenuItem(
            title: L10n("Atalho: ⌥Espaço (segure para gravar)"),
            action: nil,
            keyEquivalent: ""
        )
        shortcutItem.isEnabled = false
        menu.addItem(shortcutItem)
        menu.addItem(.separator())
    }

    private func rebuildMenu() {
        modeItems.removeAll()
        menu.removeAllItems()

        settingsItem.title = L10n("Ajustes…")
        axItem.title = L10n("Habilitar Acessibilidade…")
        axItem.image = NSImage(
            systemSymbolName: "exclamationmark.triangle.fill",
            accessibilityDescription: L10n("Alerta")
        )
        axItem.image?.isTemplate = false

        buildStaticMenuItems()
        buildModeItems()

        let transcribeItem = NSMenuItem(
            title: L10n("Transcrever Arquivo…"),
            action: #selector(StatusBarController.showTranscribe),
            keyEquivalent: "o"
        )
        transcribeItem.target = self
        menu.addItem(transcribeItem)

        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: L10n("Sair do Fala"),
            action: #selector(StatusBarController.quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        menu.delegate = self
        statusItem.menu = menu
    }

    private func buildModeItems() {
        let modeHeader = NSMenuItem(title: L10n("Modo de Captura:"), action: nil, keyEquivalent: "")
        modeHeader.isEnabled = false
        menu.addItem(modeHeader)

        for mode in settings.readiness.quickMenuModes() {
            let item = NSMenuItem(
                title: mode.localizedName,
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
        if settings.readiness.quickMenuModes().count != modeItems.count {
            rebuildMenu()
        }

        // Update Checkmarks and dynamic titles for Modes
        let currentMode = settings.selectedDictationTemplate
        for item in modeItems {
            if let modeRaw = item.representedObject as? String {
                item.state = (modeRaw == currentMode.rawValue) ? .on : .off
                // Update custom mode title dynamically
                if modeRaw == DictationTemplate.custom.rawValue {
                    let name = settings.customModeName.trimmingCharacters(in: .whitespacesAndNewlines)
                    item.title = name.isEmpty ? DictationTemplate.custom.localizedName : name
                } else {
                    item.image = nil
                }
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
            guard settings.readiness.isModeVisibleInQuickMenu(mode) else {
                return
            }
            settings.selectedDictationTemplate = mode
            settings.save()
        }
    }

    public func setState(_ state: AppState) {
        currentState = state
        let (name, description): (String, String) = switch state {
        case .idle: ("mic", L10n("Fala — pronto"))
        case .loading: ("arrow.down.circle", L10n("Fala — carregando modelo…"))
        case .recording: ("mic.fill", L10n("Fala — gravando"))
        case .transcribing: ("waveform", L10n("Fala — transcrevendo…"))
        }
        statusItem.button?.image = NSImage(systemSymbolName: name, accessibilityDescription: description)
    }

    public func reloadLocalizedContent() {
        rebuildMenu()
        setState(currentState)
    }

    public func setLoadingTooltip(_ message: String?) {
        statusItem.button?.toolTip = message
    }

    public func setDownloadProgress(_ fraction: Double, modelName: String) {
        let pct = Int(fraction * 100)
        statusItem.button?.toolTip = String(format: L10n("Baixando %@… %d%%"), modelName, pct)
    }

    public func showTemporaryWarning(_ message: String) {
        statusItem.button?.image = NSImage(
            systemSymbolName: "exclamationmark.triangle",
            accessibilityDescription: message
        )
        statusItem.button?.toolTip = message
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            self.statusItem.button?.toolTip = nil
            self.setState(.idle)
        }
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
