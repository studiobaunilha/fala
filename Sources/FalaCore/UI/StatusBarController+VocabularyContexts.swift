import AppKit

extension StatusBarController {
    func buildVocabularyContextMenu() {
        let current = settings.effectiveVocabularyContext.displayName
        let item = NSMenuItem(title: L10n("Contexto:") + " " + current, action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        if settings.vocabularyContextsEnabled {
            addContextChoice(title: L10n("Padrão"), id: nil, to: submenu)
            for context in settings.vocabularyContexts {
                addContextChoice(title: context.name, id: context.id, to: submenu)
            }
            submenu.addItem(.separator())
        }
        let manage = NSMenuItem(title: L10n("Gerenciar contextos…"), action: #selector(showContexts), keyEquivalent: "")
        manage.target = self
        submenu.addItem(manage)
        item.submenu = submenu
        menu.addItem(item)
        menu.addItem(.separator())
    }

    func addContextChoice(title: String, id: UUID?, to submenu: NSMenu) {
        let item = NSMenuItem(title: title, action: #selector(selectContext(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = id?.uuidString ?? ""
        item.state = settings.effectiveVocabularyContext.id == id ? .on : .off
        submenu.addItem(item)
    }

    @objc func selectContext(_ sender: NSMenuItem) {
        settings.selectVocabularyContext(id: (sender.representedObject as? String).flatMap(UUID.init(uuidString:)))
    }

    @objc func showContexts() {
        settings.openSettingsSelection?(.panel(.contexts))
    }
}
