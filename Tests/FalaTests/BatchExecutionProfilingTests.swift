import XCTest
@testable import FalaCore

final class BatchExecutionProfilingTests: XCTestCase {

    func testDebugSummaryIncludesModesOutcomeAndDurations() {
        let metrics = BatchExecutionMetrics(
            fileName: "entrevista.m4a",
            fileExtension: "m4a",
            inputFileSize: 2_621_440,
            audioDuration: 125.3,
            usedPostProcessing: false,
            audioPreparationMode: .converted,
            modelLoadState: .ready,
            outcome: .succeeded,
            audioPreparation: .milliseconds(420),
            modelPreparation: .milliseconds(35),
            transcription: .seconds(2),
            postProcessing: nil,
            fileSaving: .milliseconds(12),
            total: .milliseconds(2_455)
        )

        XCTAssertEqual(
            metrics.debugSummary,
            "file=entrevista.m4a ext=m4a size=2.5MB duration=2m05.3s "
                + "audioMode=converted modelState=ready outcome=succeeded "
                + "prepare=0.420s model=0.035s transcribe=2.000s "
                + "post=n/a save=0.012s total=2.455s"
        )
    }
}
