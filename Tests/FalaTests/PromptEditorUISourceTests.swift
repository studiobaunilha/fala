import XCTest

final class PromptEditorUISourceTests: XCTestCase {
    func testPromptEditorComponentIsSharedAcrossSettingsAndBatch() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let files = [
            "Sources/FalaCore/UI/SettingsView+Modes.swift",
            "Sources/FalaCore/UI/TranscribeView+Ext.swift"
        ].map { repoRoot.appendingPathComponent($0) }

        for fileURL in files {
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            XCTAssertTrue(
                source.contains("PromptEditorPanel("),
                "\(fileURL.lastPathComponent) should reuse PromptEditorPanel"
            )
        }
    }

    func testApplePromptIsNoLongerReadOnlyInModeDetails() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let modesURL = repoRoot.appendingPathComponent("Sources/FalaCore/UI/SettingsView+Modes.swift")
        let readinessURL = repoRoot.appendingPathComponent(
            "Sources/FalaCore/App/RuntimeReadinessEvaluator.swift"
        )
        let settingsURL = repoRoot.appendingPathComponent("Sources/FalaCore/UI/SettingsView.swift")

        let modesSource = try String(contentsOf: modesURL, encoding: .utf8)
        let readinessSource = try String(contentsOf: readinessURL, encoding: .utf8)
        let settingsSource = try String(contentsOf: settingsURL, encoding: .utf8)

        XCTAssertFalse(modesSource.contains("Prompt do Sistema (Somente Leitura)"))
        XCTAssertFalse(modesSource.contains("Prompt somente-leitura"))
        XCTAssertFalse(readinessSource.contains("Modo incompatível com Apple Intelligence"))
        XCTAssertFalse(settingsSource.contains("Modo personalizado requer provedor diferente do Apple Intelligence"))
    }

    func testModeDetailsUseGlobalLLMSelection() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let modesURL = repoRoot.appendingPathComponent("Sources/FalaCore/UI/SettingsView+Modes.swift")
        let modesSource = try String(contentsOf: modesURL, encoding: .utf8)

        XCTAssertFalse(modesSource.contains("@State private var provider"))
        XCTAssertFalse(modesSource.contains("@State private var model"))
        XCTAssertFalse(modesSource.contains("Picker(L10n(\"Provedor LLM\"), selection: $provider)"))
        XCTAssertTrue(modesSource.contains("settings.openSettings(.panel(.llm))"))
        XCTAssertTrue(modesSource.contains("config.provider = nil"))
        XCTAssertTrue(modesSource.contains("config.model = nil"))
    }
}
