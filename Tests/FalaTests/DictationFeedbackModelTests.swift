import XCTest
@testable import FalaCore

@MainActor
final class DictationFeedbackModelTests: XCTestCase {

    func testPushRMSNormalisesToZeroOneRange() {
        let model = DictationFeedbackModel()
        model.pushRMS(0.05) // typical speech RMS
        XCTAssertEqual(model.rmsLevel, 0.5, accuracy: 0.01)
    }

    func testPushRMSClampsToOne() {
        let model = DictationFeedbackModel()
        model.pushRMS(0.2) // very loud — 0.2 * 10 = 2.0, clamped to 1.0
        XCTAssertEqual(model.rmsLevel, 1.0)
    }

    func testRMSHistoryCappedAtTwelve() {
        let model = DictationFeedbackModel()
        for idx in 0..<20 {
            model.pushRMS(Float(idx) * 0.005)
        }
        XCTAssertEqual(model.rmsHistory.count, 12)
    }

    func testResetClearsAllState() {
        let model = DictationFeedbackModel()
        model.stage = .transcribing
        model.pushRMS(0.05)
        model.isVisible = true

        model.reset()

        XCTAssertEqual(model.stage, .recording)
        XCTAssertEqual(model.rmsLevel, 0)
        XCTAssertFalse(model.isVisible)
        XCTAssertEqual(model.rmsHistory.count, 12)
        XCTAssertTrue(model.rmsHistory.allSatisfy { $0 == 0 })
    }
}
