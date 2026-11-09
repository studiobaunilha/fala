import AppKit
import XCTest
@testable import FalaCore

@MainActor
final class AppRestartCoordinatorTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AppLocalization.apply(languageCode: "pt-BR")
    }

    override func tearDown() {
        AppLocalization.apply(languageCode: "auto")
        super.tearDown()
    }

    func testApplicationRelauncherRequestsNewApplicationInstance() {
        let workspace = StubWorkspaceLauncher()
        let relauncher = ApplicationRelauncher(
            workspace: workspace,
            bundleURLProvider: { URL(fileURLWithPath: "/tmp/Fala.app") }
        )

        relauncher.relaunch { _ in }

        XCTAssertEqual(workspace.openCallCount, 1)
        XCTAssertEqual(workspace.lastURL?.path, "/tmp/Fala.app")
        XCTAssertTrue(workspace.lastConfiguration?.activates == true)
        XCTAssertTrue(workspace.lastConfiguration?.createsNewApplicationInstance == true)
    }

    func testConfirmAndRestartLaunchesNewInstanceBeforeTerminating() {
        let prompt = StubRestartPromptPresenter(shouldConfirm: true)
        let relauncher = StubAppRelauncher(result: .launched)
        let failurePresenter = StubRestartFailurePresenter()
        var appliedChanges = 0
        var terminateCallCount = 0

        let coordinator = AppRestartCoordinator(
            promptPresenter: prompt,
            relauncher: relauncher,
            failurePresenter: failurePresenter,
            terminationHandler: { terminateCallCount += 1 }
        )

        let didConfirm = coordinator.confirmAndRestart(
            title: "Reinício necessário",
            message: "Trocar o motor exige reiniciar."
        ) {
            appliedChanges += 1
        }

        XCTAssertTrue(didConfirm)
        XCTAssertEqual(appliedChanges, 1)
        XCTAssertEqual(relauncher.relaunchCallCount, 1)
        XCTAssertEqual(terminateCallCount, 1)
        XCTAssertEqual(failurePresenter.presentCallCount, 0)
        XCTAssertTrue(relauncher.didRequestNewApplicationInstance)
    }

    func testConfirmAndRestartPresentsManualFallbackWhenRelaunchFails() {
        let prompt = StubRestartPromptPresenter(shouldConfirm: true)
        let relauncher = StubAppRelauncher(result: .failed)
        let failurePresenter = StubRestartFailurePresenter()
        var terminateCallCount = 0

        let coordinator = AppRestartCoordinator(
            promptPresenter: prompt,
            relauncher: relauncher,
            failurePresenter: failurePresenter,
            terminationHandler: { terminateCallCount += 1 }
        )

        let didConfirm = coordinator.confirmAndRestart(
            title: "Reinício necessário",
            message: "Trocar o motor exige reiniciar."
        ) {}

        XCTAssertTrue(didConfirm)
        XCTAssertEqual(relauncher.relaunchCallCount, 1)
        XCTAssertEqual(terminateCallCount, 0)
        XCTAssertEqual(failurePresenter.presentCallCount, 1)
        XCTAssertEqual(failurePresenter.lastTitle, "Feche e abra novamente")
    }

    func testConfirmAndRestartDoesNothingWhenUserCancels() {
        let prompt = StubRestartPromptPresenter(shouldConfirm: false)
        let relauncher = StubAppRelauncher(result: .launched)
        let failurePresenter = StubRestartFailurePresenter()
        var appliedChanges = 0
        var terminateCallCount = 0

        let coordinator = AppRestartCoordinator(
            promptPresenter: prompt,
            relauncher: relauncher,
            failurePresenter: failurePresenter,
            terminationHandler: { terminateCallCount += 1 }
        )

        let didConfirm = coordinator.confirmAndRestart(
            title: "Reinício necessário",
            message: "Trocar o motor exige reiniciar."
        ) {
            appliedChanges += 1
        }

        XCTAssertFalse(didConfirm)
        XCTAssertEqual(appliedChanges, 0)
        XCTAssertEqual(relauncher.relaunchCallCount, 0)
        XCTAssertEqual(terminateCallCount, 0)
        XCTAssertEqual(failurePresenter.presentCallCount, 0)
    }
}

@MainActor
private final class StubRestartPromptPresenter: RestartPromptPresenting {
    let shouldConfirm: Bool

    init(shouldConfirm: Bool) {
        self.shouldConfirm = shouldConfirm
    }

    func confirmRestart(
        title: String,
        message: String,
        confirmTitle: String,
        cancelTitle: String
    ) -> Bool {
        shouldConfirm
    }
}

@MainActor
private final class StubAppRelauncher: AppRelaunching {
    private let result: AppRelaunchResult
    private(set) var relaunchCallCount = 0
    private(set) var didRequestNewApplicationInstance = false

    init(result: AppRelaunchResult) {
        self.result = result
    }

    func relaunch(completion: @escaping @MainActor (AppRelaunchResult) -> Void) {
        relaunchCallCount += 1
        didRequestNewApplicationInstance = true
        completion(result)
    }
}

@MainActor
private final class StubRestartFailurePresenter: RestartFailurePresenting {
    private(set) var presentCallCount = 0
    private(set) var lastTitle: String?

    func presentManualRestartInstructions(
        title: String,
        message: String,
        acknowledgeTitle: String
    ) {
        presentCallCount += 1
        lastTitle = title
    }
}

@MainActor
private final class StubWorkspaceLauncher: WorkspaceApplicationLaunching {
    private(set) var openCallCount = 0
    private(set) var lastURL: URL?
    private(set) var lastConfiguration: NSWorkspace.OpenConfiguration?

    func openApplication(
        at url: URL,
        configuration: NSWorkspace.OpenConfiguration,
        completion: @escaping @MainActor (Error?) -> Void
    ) {
        openCallCount += 1
        lastURL = url
        lastConfiguration = configuration
        completion(nil)
    }
}
