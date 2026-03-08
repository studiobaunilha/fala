import XCTest

final class TranscribeQueueUISourceTests: XCTestCase {
    func testTranscribeFlowUsesQueueAndMultipleSelection() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let jobURL = repoRoot.appendingPathComponent("Sources/FalaCore/UI/TranscriptionJob.swift")
        let viewURL = repoRoot.appendingPathComponent("Sources/FalaCore/UI/TranscribeView.swift")
        let extURL = repoRoot.appendingPathComponent("Sources/FalaCore/UI/TranscribeView+Ext.swift")
        let queueURL = repoRoot.appendingPathComponent("Sources/FalaCore/UI/TranscribeView+Queue.swift")

        let jobSource = try String(contentsOf: jobURL, encoding: .utf8)
        let viewSource = try String(contentsOf: viewURL, encoding: .utf8)
        let extSource = try String(contentsOf: extURL, encoding: .utf8)
        let queueSource = try String(contentsOf: queueURL, encoding: .utf8)
        let combinedTranscribeSource = extSource + "\n" + queueSource

        XCTAssertTrue(jobSource.contains("panel.allowsMultipleSelection = true"))
        XCTAssertTrue(jobSource.contains("enqueueInputFiles(panel.urls)"))
        XCTAssertTrue(viewSource.contains("job.queue.isEmpty"))
        XCTAssertTrue(viewSource.contains("job.enqueueInputFiles(items)"))
        XCTAssertTrue(combinedTranscribeSource.contains("L10n(\"Fila de Arquivos\")"))
        XCTAssertTrue(combinedTranscribeSource.contains("L10n(\"Adicionar Arquivos…\")"))
    }
}
