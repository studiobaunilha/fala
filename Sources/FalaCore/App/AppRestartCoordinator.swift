import AppKit

@MainActor
public protocol RestartPromptPresenting: AnyObject {
    func confirmRestart(
        title: String,
        message: String,
        confirmTitle: String,
        cancelTitle: String
    ) -> Bool
}

@MainActor
public protocol AppRelaunching: AnyObject {
    func relaunch()
}

@MainActor
public final class NSAlertRestartPromptPresenter: RestartPromptPresenting {
    public init() {}

    public func confirmRestart(
        title: String,
        message: String,
        confirmTitle: String,
        cancelTitle: String
    ) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: confirmTitle)
        alert.addButton(withTitle: cancelTitle)
        return alert.runModal() == .alertFirstButtonReturn
    }
}

@MainActor
public final class ApplicationRelauncher: AppRelaunching {
    public init() {}

    public func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        NSWorkspace.shared.openApplication(
            at: Bundle.main.bundleURL,
            configuration: configuration
        ) { _, error in
            if let error {
                NSLog("[Fala] Failed to relaunch app: %@", error.localizedDescription)
                return
            }

            Task { @MainActor in
                NSApp.terminate(nil)
            }
        }
    }
}

@MainActor
public final class AppRestartCoordinator {
    private let promptPresenter: RestartPromptPresenting
    private let relauncher: AppRelaunching

    public init(
        promptPresenter: RestartPromptPresenting = NSAlertRestartPromptPresenter(),
        relauncher: AppRelaunching = ApplicationRelauncher()
    ) {
        self.promptPresenter = promptPresenter
        self.relauncher = relauncher
    }

    @discardableResult
    public func confirmAndRestart(
        title: String,
        message: String,
        confirmTitle: String = L10n("Reiniciar agora"),
        cancelTitle: String = L10n("Cancelar"),
        applyChanges: () -> Void
    ) -> Bool {
        let confirmed = promptPresenter.confirmRestart(
            title: title,
            message: message,
            confirmTitle: confirmTitle,
            cancelTitle: cancelTitle
        )

        guard confirmed else {
            return false
        }

        applyChanges()
        relauncher.relaunch()
        return true
    }
}
