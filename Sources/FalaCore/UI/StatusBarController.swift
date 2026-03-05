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

        settingsItem = NSMenuItem(
            title: L10n("Ajustes…"),
            action: #selector(StatusBarController.showSettings),
            keyEquivalent: ","
        )

        axItem = NSMenuItem(
            title: L10n("Habilitar Acessibilidade…"),
            action: #selector(StatusBarController.openAccessibilitySettings),
            keyEquivalent: ""
        )
        axItem.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill",
                               accessibilityDescription: L10n("Alerta"))
        axItem.image?.isTemplate = false

        super.init()

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

        axItem.target = self
        
        menu.delegate = self
        statusItem.menu = menu

        setState(.idle)
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

    private func buildModeItems() {
        let modeHeader = NSMenuItem(title: L10n("Modo de Captura:"), action: nil, keyEquivalent: "")
        modeHeader.isEnabled = false
        menu.addItem(modeHeader)
        
        for mode in DictationTemplate.allCases {
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
        // Update Checkmarks and dynamic titles for Modes
        let currentMode = settings.selectedDictationTemplate
        let isWhisper = settings.transcriptionEngine == "whisper"
        for item in modeItems {
            if let modeRaw = item.representedObject as? String {
                item.state = (modeRaw == currentMode.rawValue) ? .on : .off
                // Update custom mode title dynamically
                if modeRaw == DictationTemplate.custom.rawValue {
                    let name = settings.customModeName.trimmingCharacters(in: .whitespacesAndNewlines)
                    item.title = name.isEmpty ? DictationTemplate.custom.localizedName : name
                }
                // Show warning icon on translate when engine is not Whisper
                if modeRaw == DictationTemplate.translate.rawValue {
                    let baseName = DictationTemplate.translate.localizedName
                    item.title = baseName
                    if !isWhisper {
                        item.image = NSImage(
                            systemSymbolName: "exclamationmark.triangle.fill",
                            accessibilityDescription: L10n("Incompatível")
                        )
                        item.image?.isTemplate = false
                    } else {
                        item.image = nil
                    }
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
            // Warn if selecting translate without Whisper
            if mode == .translate && settings.transcriptionEngine != "whisper" {
                showTranslateAlert()
                return
            }
            settings.selectedDictationTemplate = mode
            settings.save()
        }
    }

    private func showTranslateAlert() {
        let alert = NSAlert()
        alert.messageText = L10n("Motor incompatível")
        // swiftlint:disable:next line_length
        alert.informativeText = L10n("A tradução para inglês é um recurso exclusivo do Whisper. O motor atual (Parakeet) não suporta tradução. Deseja trocar para o Whisper?")
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n("Trocar para Whisper"))
        alert.addButton(withTitle: L10n("Cancelar"))
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            settings.transcriptionEngine = "whisper"
            settings.selectedDictationTemplate = .translate
            settings.save()
        }
    }

    public func setState(_ state: AppState) {
        let (name, description): (String, String) = switch state {
        case .idle: ("mic", L10n("Fala — pronto"))
        case .loading: ("arrow.down.circle", L10n("Fala — carregando modelo…"))
        case .recording: ("mic.fill", L10n("Fala — gravando"))
        case .transcribing: ("waveform", L10n("Fala — transcrevendo…"))
        }
        statusItem.button?.image = NSImage(systemSymbolName: name, accessibilityDescription: description)
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
