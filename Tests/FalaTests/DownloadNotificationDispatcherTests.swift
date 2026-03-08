import XCTest
@testable import FalaCore

final class DownloadNotificationDispatcherTests: XCTestCase {
    actor DeliveryState {
        private(set) var deliveredOnMainThread = false

        func setDelivered(onMainThread: Bool) {
            deliveredOnMainThread = onMainThread
        }
    }

    func testPostMLXDownloadCompletedDeliversNotificationOnMainThread() async {
        let center = NotificationCenter()
        let expectation = expectation(description: "notification delivered")
        let deliveryState = DeliveryState()

        let token = center.addObserver(
            forName: .mlxDownloadCompleted,
            object: nil,
            queue: nil
        ) { _ in
            let deliveredOnMainThread = Thread.isMainThread
            Task {
                await deliveryState.setDelivered(onMainThread: deliveredOnMainThread)
                expectation.fulfill()
            }
        }
        defer { center.removeObserver(token) }

        await Task.detached {
            await DownloadNotificationDispatcher.postMLXDownloadCompleted(
                repoID: "mlx-community/test-model",
                shortID: "test-model",
                center: center
            )
        }.value

        await fulfillment(of: [expectation], timeout: 1)
        let deliveredOnMainThread = await deliveryState.deliveredOnMainThread
        XCTAssertTrue(deliveredOnMainThread)
    }
}
