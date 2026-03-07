import XCTest
@testable import FalaCore

@MainActor
final class RuntimeReadinessEvaluatorTests: XCTestCase {
    override func setUp() async throws {
        await MainActor.run {
            LicenseManager.shared.setTestActivated(true)
        }
    }

    override func tearDown() async throws {
        await MainActor.run {
            LicenseManager.shared.setTestActivated(false)
        }
    }

    func testUnsupportedMLXSelectionBlocksLLMMode() {
        var config = AppConfig()
        config.selectedDictationTemplate = .askAI
        config.llmProvider = "mlx"
        config.mlxModel = "mlx-community/Qwen3.5-4B-MLX-4bit"

        let settings = AppSettings(
            config: config,
            transcriber: Transcriber(modelName: config.dictationModel),
            modelManager: ModelManager(),
            permissionProvider: ReadinessPermissionProvider()
        )

        let issues = settings.readiness.issuesForDictation()

        XCTAssertTrue(issues.contains {
            $0.kind == .mlxModelMissing && $0.title == "Modelo MLX incompatível"
        })
    }
}

@MainActor
private final class ReadinessPermissionProvider: SystemPermissionProviding {
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
