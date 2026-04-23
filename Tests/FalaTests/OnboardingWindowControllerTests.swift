import AppKit
import XCTest
@testable import FalaCore

@MainActor
final class OnboardingWindowControllerTests: XCTestCase {
    override func setUp() async throws {
        await MainActor.run {
            AnimationConfig.enabled = false
            LicenseManager.shared.setTestActivated(true)
        }
    }

    override func tearDown() async throws {
        await MainActor.run {
            LicenseManager.shared.setTestActivated(false)
        }
    }

    func testOnboardingWindowUsesExpandedFittedHeight() {
        let suiteName = "OnboardingWindowControllerTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Expected isolated defaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let permissionProvider = StubPermissionProvider()
        var config = AppConfig()
        config.transcriptionEngine = "parakeet"

        let settings = AppSettings(
            config: config,
            transcriber: Transcriber(
                modelName: config.dictationModel,
                language: config.transcriptionLanguage,
                temperature: config.dictationTemperature,
                prompt: ""
            ),
            modelManager: ModelManager(),
            permissionProvider: permissionProvider
        )
        let viewModel = OnboardingViewModel(
            settings: settings,
            readiness: settings.readiness,
            permissionProvider: permissionProvider,
            defaults: defaults
        )
        let controller = OnboardingWindowController(viewModel: viewModel)

        controller.showIfNeeded()

        guard let window = controller.currentWindow else {
            return XCTFail("Onboarding window should be visible")
        }

        XCTAssertGreaterThan(window.contentLayoutRect.height, 520)
        XCTAssertGreaterThanOrEqual(
            window.contentLayoutRect.height,
            WindowSize.onboardingMinHeight
        )
        XCTAssertEqual(
            window.contentLayoutRect.width,
            WindowSize.onboardingDefaultWidth,
            accuracy: 0.5
        )

        window.orderOut(nil)
    }

    func testViewModelOnlyRequestsSettingsAutoOpenOnFirstCompletion() {
        let suiteName = "OnboardingWindowControllerTests.Settings.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Expected isolated defaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let permissionProvider = StubPermissionProvider()
        let config = AppConfig()
        let settings = AppSettings(
            config: config,
            transcriber: Transcriber(modelName: config.dictationModel),
            modelManager: ModelManager(),
            permissionProvider: permissionProvider
        )
        let viewModel = OnboardingViewModel(
            settings: settings,
            readiness: settings.readiness,
            permissionProvider: permissionProvider,
            defaults: defaults
        )

        XCTAssertTrue(viewModel.shouldOpenSettingsAfterContinue)

        viewModel.markCompleted()

        XCTAssertFalse(viewModel.shouldOpenSettingsAfterContinue)
    }
}

@MainActor
private final class StubPermissionProvider: SystemPermissionProviding {
    func microphonePermissionState() -> MicrophonePermissionState {
        .granted
    }

    func requestMicrophoneAccess() async -> Bool {
        true
    }

    func isAccessibilityTrusted() -> Bool {
        true
    }

    func openMicrophoneSettings() {}

    func openAccessibilitySettings() {}
}
