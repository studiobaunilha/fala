import AppKit

@MainActor
enum AppMainMenu {
    static func install(appDelegate: AppDelegate) {
        let app = NSApp ?? NSApplication.shared
        let mainMenu = NSMenu()
        mainMenu.addItem(makeAppMenuItem(appDelegate: appDelegate))
        mainMenu.addItem(makeEditMenuItem())
        app.mainMenu = mainMenu
    }

    private static func makeAppMenuItem(appDelegate: AppDelegate) -> NSMenuItem {
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        let settingsItem = NSMenuItem(
            title: L10n("Ajustes…"),
            action: #selector(AppDelegate.showSettingsWindow),
            keyEquivalent: ","
        )
        settingsItem.target = appDelegate
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())

        let hideItem = NSMenuItem(
            title: L10n("Ocultar Fala"),
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )
        hideItem.target = NSApp
        appMenu.addItem(hideItem)

        let quitItem = NSMenuItem(
            title: L10n("Sair do Fala"),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = NSApp
        appMenu.addItem(quitItem)

        return appMenuItem
    }

    private static func makeEditMenuItem() -> NSMenuItem {
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: L10n("Editar"))
        editMenuItem.submenu = editMenu

        let undoItem = NSMenuItem(
            title: L10n("Desfazer"),
            action: #selector(UndoManager.undo),
            keyEquivalent: "z"
        )
        let redoItem = NSMenuItem(
            title: L10n("Refazer"),
            action: #selector(UndoManager.redo),
            keyEquivalent: "Z"
        )
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        let cutItem = NSMenuItem(
            title: L10n("Recortar"),
            action: #selector(NSText.cut(_:)),
            keyEquivalent: "x"
        )
        let copyItem = NSMenuItem(
            title: L10n("Copiar"),
            action: #selector(NSText.copy(_:)),
            keyEquivalent: "c"
        )
        let pasteItem = NSMenuItem(
            title: L10n("Colar"),
            action: #selector(NSText.paste(_:)),
            keyEquivalent: "v"
        )
        let selectAllItem = NSMenuItem(
            title: L10n("Selecionar Tudo"),
            action: #selector(NSText.selectAll(_:)),
            keyEquivalent: "a"
        )

        [undoItem, redoItem, cutItem, copyItem, pasteItem, selectAllItem].forEach {
            $0.target = nil
        }

        editMenu.addItem(undoItem)
        editMenu.addItem(redoItem)
        editMenu.addItem(.separator())
        editMenu.addItem(cutItem)
        editMenu.addItem(copyItem)
        editMenu.addItem(pasteItem)
        editMenu.addItem(.separator())
        editMenu.addItem(selectAllItem)

        return editMenuItem
    }
}
