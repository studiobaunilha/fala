import XCTest

final class SettingsNavigationSourceTests: XCTestCase {
    func testSettingsPanelsCollapseApplicationMetaScreensIntoMainSidebar() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let panelURL = repoRoot.appendingPathComponent("Sources/FalaCore/UI/SettingsPanel.swift")
        let settingsViewURL = repoRoot.appendingPathComponent("Sources/FalaCore/UI/SettingsView.swift")
        let extURL = repoRoot.appendingPathComponent("Sources/FalaCore/UI/SettingsView+Ext.swift")

        let panelSource = try String(contentsOf: panelURL, encoding: .utf8)
        let settingsViewSource = try String(contentsOf: settingsViewURL, encoding: .utf8)
        let extSource = try String(contentsOf: extURL, encoding: .utf8)

        XCTAssertFalse(panelSource.contains("case license"))
        XCTAssertFalse(panelSource.contains("case updates"))
        XCTAssertFalse(panelSource.contains("case about"))
        XCTAssertTrue(panelSource.contains("return L10n(\"Transcrição de Arquivos\")"))

        XCTAssertFalse(settingsViewSource.contains("case .license"))
        XCTAssertFalse(settingsViewSource.contains("case .updates"))
        XCTAssertFalse(settingsViewSource.contains("case .about"))
        XCTAssertTrue(settingsViewSource.contains("fileTranscriptionView"))

        XCTAssertTrue(extSource.contains("updatesPreferencesSection"))
        XCTAssertTrue(extSource.contains("licenseStatusSection"))
        XCTAssertTrue(extSource.contains("aboutApplicationSection"))
    }
}
