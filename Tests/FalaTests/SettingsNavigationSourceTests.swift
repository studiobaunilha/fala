import XCTest

final class SettingsNavigationSourceTests: XCTestCase {
    func testSettingsPanelsStructure() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let panelURL = repoRoot.appendingPathComponent("Sources/FalaCore/UI/SettingsPanel.swift")
        let settingsViewURL = repoRoot.appendingPathComponent("Sources/FalaCore/UI/SettingsView.swift")
        let extURL = repoRoot.appendingPathComponent("Sources/FalaCore/UI/SettingsView+Ext.swift")
        let aboutPanelURL = repoRoot.appendingPathComponent("Sources/FalaCore/UI/SettingsView+AboutPanel.swift")

        let panelSource = try String(contentsOf: panelURL, encoding: .utf8)
        let settingsViewSource = try String(contentsOf: settingsViewURL, encoding: .utf8)
        let extSource = try String(contentsOf: extURL, encoding: .utf8)
        let aboutPanelSource = try String(contentsOf: aboutPanelURL, encoding: .utf8)

        // License and updates should not be standalone panels
        XCTAssertFalse(panelSource.contains("case license"))
        XCTAssertFalse(panelSource.contains("case updates"))
        XCTAssertFalse(panelSource.contains("case advanced"))

        // About and support are proper sidebar panels
        XCTAssertTrue(panelSource.contains("case about"))
        XCTAssertTrue(panelSource.contains("case support"))
        XCTAssertTrue(settingsViewSource.contains("case .about"))
        XCTAssertTrue(settingsViewSource.contains("case .support"))
        XCTAssertFalse(settingsViewSource.contains("case .advanced"))
        XCTAssertFalse(settingsViewSource.contains("fileTranscriptionView"))

        // General panel now also owns file transcription defaults and global replacements
        XCTAssertTrue(extSource.contains("systemShortcutSection"))
        XCTAssertTrue(extSource.contains("appLanguageSection"))
        XCTAssertTrue(extSource.contains("fileExportSection"))
        XCTAssertTrue(extSource.contains("replacementRulesSection"))

        // About panel aggregates identity, updates, license and about sections
        XCTAssertTrue(aboutPanelSource.contains("applicationIdentitySection"))
        XCTAssertTrue(aboutPanelSource.contains("updatesPreferencesSection"))
        XCTAssertTrue(aboutPanelSource.contains("licenseStatusSection"))
        XCTAssertTrue(aboutPanelSource.contains("aboutApplicationSection"))
    }
}
