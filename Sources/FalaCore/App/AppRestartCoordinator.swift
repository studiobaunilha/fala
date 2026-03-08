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
    func relaunch(completion: @escaping @MainActor (AppRelaunchResult) -> Void)
}

@MainActor
public protocol WorkspaceApplicationLaunching: AnyObject {
    func openApplication(
        at url: URL,
        configuration: NSWorkspace.OpenConfiguration,
        completion: @escaping @MainActor (Error?) -> Void
    )
}

public enum AppRelaunchResult: Equatable {
    case launched
    case failed
}

@MainActor
public protocol RestartFailurePresenting: AnyObject {
    func presentManualRestartInstructions(
        title: String,
        message: String,
        acknowledgeTitle: String
    )
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
extension NSWorkspace: WorkspaceApplicationLaunching {
    public func openApplication(
        at url: URL,
        configuration: NSWorkspace.OpenConfiguration,
        completion: @escaping @MainActor (Error?) -> Void
    ) {
        openApplication(at: url, configuration: configuration) { _, error in
            Task { @MainActor in
                completion(error)
            }
        }
    }
}

@MainActor
public final class ApplicationRelauncher: AppRelaunching {
    private let workspace: WorkspaceApplicationLaunching
    private let bundleURLProvider: @MainActor () -> URL

    public init(
        workspace: WorkspaceApplicationLaunching = NSWorkspace.shared,
        bundleURLProvider: @escaping @MainActor () -> URL = { Bundle.main.bundleURL }
    ) {
        self.workspace = workspace
        self.bundleURLProvider = bundleURLProvider
    }

    public func relaunch(completion: @escaping @MainActor (AppRelaunchResult) -> Void) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = true

        workspace.openApplication(
            at: bundleURLProvider(),
            configuration: configuration
        ) { error in
            if let error {
                NSLog("[Fala] Failed to relaunch app: %@", error.localizedDescription)
                completion(.failed)
                return
            }

            completion(.launched)
        }
    }
}

@MainActor
public final class NSAlertRestartFailurePresenter: RestartFailurePresenting {
    public init() {}

    public func presentManualRestartInstructions(
        title: String,
        message: String,
        acknowledgeTitle: String
    ) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: acknowledgeTitle)
        alert.runModal()
    }
}

@MainActor
public final class AppRestartCoordinator {
    private let promptPresenter: RestartPromptPresenting
    private let relauncher: AppRelaunching
    private let failurePresenter: RestartFailurePresenting
    private let terminationHandler: @MainActor () -> Void

    public init(
        promptPresenter: RestartPromptPresenting = NSAlertRestartPromptPresenter(),
        relauncher: AppRelaunching = ApplicationRelauncher(),
        failurePresenter: RestartFailurePresenting = NSAlertRestartFailurePresenter(),
        terminationHandler: @escaping @MainActor () -> Void = { NSApp.terminate(nil) }
    ) {
        self.promptPresenter = promptPresenter
        self.relauncher = relauncher
        self.failurePresenter = failurePresenter
        self.terminationHandler = terminationHandler
    }

    @discardableResult
    public func confirmAndRestart(
        title: String,
        message: String,
        confirmTitle: String = L10n("Reiniciar agora"),
        cancelTitle: String = L10n("Cancelar"),
        fallbackTitle: String = L10n("Feche e abra novamente"),
        fallbackMessage: String = L10n("Feche o app e abra novamente para aplicar esta mudança."),
        fallbackAcknowledgeTitle: String = L10n("OK"),
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
        relauncher.relaunch { [failurePresenter, terminationHandler] result in
            switch result {
            case .launched:
                terminationHandler()
            case .failed:
                failurePresenter.presentManualRestartInstructions(
                    title: fallbackTitle,
                    message: fallbackMessage,
                    acknowledgeTitle: fallbackAcknowledgeTitle
                )
            }
        }
        return true
    }
}
