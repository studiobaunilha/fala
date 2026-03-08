import XCTest

final class WhisperCatalogUISourceTests: XCTestCase {
    func testWhisperSettingsNoLongerExposeSplitModelPickers() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fileURL = repoRoot.appendingPathComponent(
            "Sources/FalaCore/UI/SettingsView+TranscriptionModels.swift"
        )
        let source = try String(contentsOf: fileURL, encoding: .utf8)

        XCTAssertFalse(source.contains("Modelo de Ditado"))
        XCTAssertFalse(source.contains("Modelo Batch / Arquivo"))
        XCTAssertFalse(source.contains("downloadedModelPicker("))
    }

    func testWhisperSettingsUseCatalogComponents() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fileURL = repoRoot.appendingPathComponent(
            "Sources/FalaCore/UI/SettingsView+TranscriptionModels.swift"
        )
        let source = try String(contentsOf: fileURL, encoding: .utf8)

        XCTAssertTrue(source.contains("TranscriptionEngineOptionCard"))
        XCTAssertTrue(source.contains("WhisperModelSelectionSummaryView"))
        XCTAssertTrue(source.contains("WhisperCatalogModelRow"))
    }

    func testWhisperSettingsExposeDownloadActionInSummaryAndRemoveActionInRows() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fileURL = repoRoot.appendingPathComponent(
            "Sources/FalaCore/UI/SettingsView+TranscriptionModels.swift"
        )
        let source = try String(contentsOf: fileURL, encoding: .utf8)

        XCTAssertTrue(source.contains("primaryActionTitle: whisperSummaryActionTitle"))
        XCTAssertTrue(source.contains("removeAction: whisperRemoveAction"))
        XCTAssertTrue(source.contains("func whisperSummaryActionTitle("))
    }
}
