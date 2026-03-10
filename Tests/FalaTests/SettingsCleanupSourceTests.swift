import XCTest

final class SettingsCleanupSourceTests: XCTestCase {
    func testDiarizationIsRemovedFromSettingsAndBatchSources() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let files = [
            "Sources/FalaCore/Config/AppConfig.swift",
            "Sources/FalaCore/Resources/Localizable.xcstrings",
            "Sources/FalaCore/UI/AppSettings.swift",
            "Sources/FalaCore/UI/SettingsView+Ext.swift",
            "Sources/FalaCore/UI/SettingsView+Persistence.swift",
            "Sources/FalaCore/UI/TranscribeView+Ext.swift",
            "Sources/FalaCore/UI/TranscriptionJob+LLMProcessing.swift",
            "Sources/FalaCore/UI/TranscriptionJob+Queue.swift",
            "generate_xcstrings.py"
        ].map { repoRoot.appendingPathComponent($0) }

        let bannedSnippets = [
            "enableDiarization",
            "diarization",
            "múltiplos locutores",
            "multiple speakers",
            "Locutor 1"
        ]

        for fileURL in files {
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            for snippet in bannedSnippets {
                XCTAssertFalse(
                    source.localizedCaseInsensitiveContains(snippet),
                    "\(fileURL.lastPathComponent) should not reference diarization cleanup target '\(snippet)'"
                )
            }
        }
    }

    func testGlobalPromptSectionIsRemoved() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let llmSource = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/FalaCore/UI/SettingsView+LLM.swift"),
            encoding: .utf8
        )

        // The global prompt section has been replaced by per-provider PromptDefaults.
        // SettingsView+LLM no longer shows a globalSystemPrompt editor.
        XCTAssertFalse(llmSource.contains("globalPromptSection"))
        XCTAssertFalse(llmSource.contains("globalSystemPrompt"))
    }

    func testSettingsWindowRestoresNativeSidebarChrome() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let windowSource = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/FalaCore/UI/SettingsWindowController.swift"),
            encoding: .utf8
        )
        let viewSource = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/FalaCore/UI/SettingsView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(windowSource.contains("fullSizeContentView: true"))
        XCTAssertTrue(windowSource.contains("transparentTitlebar: true"))
        XCTAssertFalse(viewSource.contains(".toolbar(removing: .sidebarToggle)"))
    }

    func testOfficialDocsNoLongerAdvertiseDiarization() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let files = [
            "README.md",
            "docs/SPEC.md",
            "docs/WEBSITE_SPEC.md"
        ].map { repoRoot.appendingPathComponent($0) }

        let bannedSnippets = [
            "Diarization",
            "múltiplos locutores",
            "multiple speakers",
            "Locutor 1"
        ]

        for fileURL in files {
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            for snippet in bannedSnippets {
                XCTAssertFalse(
                    source.localizedCaseInsensitiveContains(snippet),
                    "\(fileURL.lastPathComponent) should not advertise removed diarization feature '\(snippet)'"
                )
            }
        }
    }
}
