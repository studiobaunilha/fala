import XCTest
@testable import SussurroCore

@MainActor
final class TranscriptionJobTests: XCTestCase {

    override func setUp() async throws {
        await MainActor.run { AnimationConfig.enabled = false }
    }

    func testInitialStateIsIdle() {
        let job = TranscriptionJob()
        XCTAssertEqual(job.state, .idle)
        XCTAssertNil(job.inputURL)
    }

    func testResetClearsState() {
        let job = TranscriptionJob()
        job.inputURL = URL(fileURLWithPath: "/tmp/test.wav")
        job.state = .error("Test error")

        job.reset()

        XCTAssertEqual(job.state, .idle)
        XCTAssertNil(job.inputURL)
    }

    func testTranscribeRequiresInputURL() {
        let job = TranscriptionJob()
        job.transcribe() // No inputURL set

        XCTAssertEqual(job.state, .idle) // Remains idle
    }

    func testOutputFormatDefaultsFromConfig() {
        // Just verify it doesn't crash and gets a string (from default AppConfig)
        let job = TranscriptionJob()
        XCTAssertFalse(job.outputFormat.isEmpty)
    }
}
