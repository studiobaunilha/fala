import XCTest
import MetricKit
@testable import FalaCore

@MainActor
final class CrashReporterTests: XCTestCase {

    func testCrashReporterSingletonExists() {
        let reporter = CrashReporter.shared
        XCTAssertNotNil(reporter, "Shared CrashReporter instance should be accessible.")
    }

    func testCrashReporterConformsToMXMetricManagerSubscriber() {
        let reporter = CrashReporter.shared
        XCTAssertTrue(
            reporter as Any is MXMetricManagerSubscriber,
            "CrashReporter must conform to MXMetricManagerSubscriber."
        )
    }

    func testCrashReporterLifecycleDoesNotCrash() {
        // Just verify that start() and stop() can be called sequentially without side effects
        let reporter = CrashReporter.shared
        
        reporter.start()
        reporter.stop()
        
        // No crash = pass
        XCTAssertTrue(true)
    }
}
