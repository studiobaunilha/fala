import XCTest
@testable import FalaCore

final class AppLifecyclePolicyTests: XCTestCase {
    func testApplyDisablesAutomaticAndSuddenTermination() {
        let processInfo = MockProcessInfo()

        AppLifecyclePolicy.apply(to: processInfo)

        XCTAssertEqual(
            processInfo.automaticTerminationReason,
            AppLifecyclePolicy.terminationReason
        )
        XCTAssertTrue(processInfo.didDisableSuddenTermination)
    }
}

private final class MockProcessInfo: AppLifecycleControlling {
    var automaticTerminationReason: String?
    var didDisableSuddenTermination = false

    func disableAutomaticTermination(_ reason: String) {
        automaticTerminationReason = reason
    }

    func disableSuddenTermination() {
        didDisableSuddenTermination = true
    }
}
