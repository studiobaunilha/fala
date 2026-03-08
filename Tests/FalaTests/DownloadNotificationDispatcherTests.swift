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

    func testPostWhisperModelDownloadCompletedIncludesSelectedModelPayload() async {
        let center = NotificationCenter()
        let expectation = expectation(description: "whisper notification delivered")
        let deliveryState = DeliveryState()
        let payloadState = PayloadState()

        let token = center.addObserver(
            forName: .whisperModelDownloadCompleted,
            object: nil,
            queue: nil
        ) { notification in
            let deliveredOnMainThread = Thread.isMainThread
            let modelID = notification.userInfo?["modelId"] as? String
            let variant = notification.userInfo?["variant"] as? String
            Task {
                await deliveryState.setDelivered(onMainThread: deliveredOnMainThread)
                await payloadState.set(modelID: modelID, variant: variant)
                expectation.fulfill()
            }
        }
        defer { center.removeObserver(token) }

        await Task.detached {
            await DownloadNotificationDispatcher.postWhisperModelDownloadCompleted(
                modelID: "medium",
                variant: "openai_whisper-medium",
                center: center
            )
        }.value

        await fulfillment(of: [expectation], timeout: 1)
        let deliveredOnMainThread = await deliveryState.deliveredOnMainThread
        let modelID = await payloadState.modelID
        let variant = await payloadState.variant

        XCTAssertTrue(deliveredOnMainThread)
        XCTAssertEqual(modelID, "medium")
        XCTAssertEqual(variant, "openai_whisper-medium")
    }
}

private extension DownloadNotificationDispatcherTests {
    actor PayloadState {
        private(set) var modelID: String?
        private(set) var variant: String?

        func set(modelID: String?, variant: String?) {
            self.modelID = modelID
            self.variant = variant
        }
    }
}
