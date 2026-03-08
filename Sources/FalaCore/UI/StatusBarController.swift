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
    private let symbolCatalog = StatusBarSymbolCatalog()
    private let settings: AppSettings
    private var onSettings: (() -> Void)?
    private var onTranscribe: (() -> Void)?
    private var modeItems: [NSMenuItem] = []
    private var currentState: AppState = .idle
    private var loadingMessage: String?
    private var downloadActivity: StatusBarDownloadActivity?
    private var temporaryWarningMessage: String?
    private var temporaryWarningTask: Task<Void, Never>?
    private var renderedSymbolName = "mic"
    private var presentationCount = 0
    private var imageAssignmentCount = 0
    private var lastPresentation: StatusBarPresentation?
    private var lastImageConfiguration: StatusBarSymbolConfiguration?

    var settingsItemTitleForTesting: String {
        settingsItem.title
    }

    var currentTooltipForTesting: String? {
        statusItem.button?.toolTip
    }

    var currentSymbolNameForTesting: String {
        renderedSymbolName
    }

    var renderCountForTesting: Int {
        presentationCount
    }

    var imageAssignmentCountForTesting: Int {
        imageAssignmentCount
    }

    var currentImageObjectIdentifierForTesting: ObjectIdentifier? {
        statusItem.button?.image.map(ObjectIdentifier.init)
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
        renderStatusItem()
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
        guard currentState != state else { return }
        currentState = state
        renderStatusItem()
    }

    public func reloadLocalizedContent() {
        rebuildMenu()
        renderStatusItem()
    }

    public func setLoadingTooltip(_ message: String?) {
        guard loadingMessage != message else { return }
        loadingMessage = message
        renderStatusItem()
    }

    public func setDownloadProgress(_ fraction: Double, modelName: String) {
        let nextActivity = StatusBarDownloadActivity(
            modelName: modelName,
            fraction: max(0, min(fraction, 1))
        )
        if let downloadActivity,
           downloadActivity.modelName == nextActivity.modelName,
           downloadActivity.displayPercent == nextActivity.displayPercent {
            return
        }
        downloadActivity = nextActivity
        renderStatusItem()
    }

    public func clearDownloadProgress() {
        guard downloadActivity != nil else { return }
        downloadActivity = nil
        renderStatusItem()
    }

    public func showTemporaryWarning(_ message: String) {
        temporaryWarningTask?.cancel()
        temporaryWarningMessage = message
        renderStatusItem()
        temporaryWarningTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            self.temporaryWarningMessage = nil
            self.renderStatusItem()
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

private extension StatusBarController {
    private func renderStatusItem() {
        if let warningMessage = temporaryWarningMessage {
            applyWarningPresentation(message: warningMessage)
            return
        }

        switch currentState {
        case .recording:
            applyIdleStatePresentation(symbolName: "mic.fill", description: L10n("Fala — gravando"))
        case .transcribing:
            applyIdleStatePresentation(symbolName: "waveform", description: L10n("Fala — transcrevendo…"))
        case .idle, .loading:
            if applyDownloadPresentationIfNeeded() {
                return
            }

            if let loadingMessage {
                applyPresentation(
                    symbolName: "clock.arrow.circlepath",
                    accessibilityDescription: loadingMessage,
                    toolTip: loadingMessage
                )
                return
            }

            let description = currentState == .loading
                ? L10n("Fala — carregando modelo…")
                : L10n("Fala — pronto")
            let symbolName = currentState == .loading ? "clock.arrow.circlepath" : "mic"
            applyPresentation(
                symbolName: symbolName,
                accessibilityDescription: description,
                toolTip: nil
            )
        }
    }

    func applyDownloadPresentationIfNeeded() -> Bool {
        guard let downloadActivity else {
            return false
        }

        let pct = Int(downloadActivity.fraction * 100)
        let message = String(
            format: L10n("Baixando %@… %d%%"),
            downloadActivity.modelName,
            pct
        )
        applyPresentation(
            symbolName: "arrow.down.circle",
            accessibilityDescription: message,
            toolTip: message
        )
        return true
    }

    func applyWarningPresentation(message: String) {
        applyPresentation(
            symbolName: "exclamationmark.triangle",
            accessibilityDescription: message,
            toolTip: message,
            isTemplate: true
        )
    }

    func applyIdleStatePresentation(symbolName: String, description: String) {
        applyPresentation(
            symbolName: symbolName,
            accessibilityDescription: description,
            toolTip: nil
        )
    }

    private func applyPresentation(
        symbolName: String,
        accessibilityDescription: String,
        toolTip: String?,
        isTemplate: Bool = true
    ) {
        let presentation = StatusBarPresentation(
            symbolName: symbolName,
            accessibilityDescription: accessibilityDescription,
            toolTip: toolTip,
            isTemplate: isTemplate
        )
        guard lastPresentation != presentation else { return }

        presentationCount += 1
        lastPresentation = presentation
        renderedSymbolName = symbolName
        let imageConfiguration = StatusBarSymbolConfiguration(
            symbolName: symbolName,
            isTemplate: isTemplate
        )
        if lastImageConfiguration != imageConfiguration {
            lastImageConfiguration = imageConfiguration
            let image = symbolCatalog.image(symbolName: symbolName, isTemplate: isTemplate)
            statusItem.button?.image = image
            imageAssignmentCount += 1
        }
        statusItem.button?.toolTip = toolTip
        statusItem.button?.setAccessibilityLabel(accessibilityDescription)
    }
}

private extension StatusBarController {
    static func makeSettingsItem() -> NSMenuItem {
        NSMenuItem(
            title: L10n("Ajustes…"),
            action: #selector(StatusBarController.showSettings),
            keyEquivalent: ","
        )
    }

    static func makeAccessibilityItem() -> NSMenuItem {
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

    func rebuildMenu() {
        modeItems.removeAll()
        menu.removeAllItems()
        refreshMenuLabels()
        buildStaticMenuItems()
        buildModeItems()
        buildTrailingMenuItems()
        menu.delegate = self
        statusItem.menu = menu
    }

    func refreshMenuLabels() {
        settingsItem.title = L10n("Ajustes…")
        axItem.title = L10n("Habilitar Acessibilidade…")
        axItem.image = NSImage(
            systemSymbolName: "exclamationmark.triangle.fill",
            accessibilityDescription: L10n("Alerta")
        )
        axItem.image?.isTemplate = false
    }

    func buildStaticMenuItems() {
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

    func buildModeItems() {
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

    func buildTrailingMenuItems() {
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
    }
}
