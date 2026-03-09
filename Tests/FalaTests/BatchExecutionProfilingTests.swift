import XCTest
@testable import FalaCore

final class BatchExecutionProfilingTests: XCTestCase {

    func testDebugSummaryIncludesModesOutcomeAndDurations() {
        let metrics = BatchExecutionMetrics(
            fileName: "entrevista.m4a",
            fileExtension: "m4a",
            usedPostProcessing: false,
            audioPreparationMode: .converted,
            modelLoadState: .ready,
            outcome: .succeeded,
            audioPreparation: .milliseconds(420),
            modelPreparation: .milliseconds(35),
            transcription: .seconds(2),
            postProcessing: nil,
            total: .milliseconds(2_455)
        )

        XCTAssertEqual(
            metrics.debugSummary,
            "file=entrevista.m4a ext=m4a audioMode=converted modelState=ready outcome=succeeded "
                + "prepare=0.420s model=0.035s transcribe=2.000s post=n/a total=2.455s"
        )
    }
}
