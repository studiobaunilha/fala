import XCTest
@testable import FalaCore

@MainActor
final class MLXDownloadWarmupGateTests: XCTestCase {
    func testRecentDownloadStaysInCooldownWindow() {
        let gate = MLXDownloadWarmupGate(cooldownInterval: 30)
        let baseline = Date(timeIntervalSince1970: 1_000)

        gate.recordCompletion(repoID: "mlx-community/Qwen3-4B-4bit", at: baseline)

        XCTAssertTrue(
            gate.isCoolingDown(
                repoID: "mlx-community/Qwen3-4B-4bit",
                now: baseline.addingTimeInterval(29)
            )
        )
    }

    func testExpiredDownloadLeavesCooldownWindow() {
        let gate = MLXDownloadWarmupGate(cooldownInterval: 30)
        let baseline = Date(timeIntervalSince1970: 1_000)

        gate.recordCompletion(repoID: "mlx-community/Qwen3-4B-4bit", at: baseline)

        XCTAssertFalse(
            gate.isCoolingDown(
                repoID: "mlx-community/Qwen3-4B-4bit",
                now: baseline.addingTimeInterval(31)
            )
        )
    }
}
