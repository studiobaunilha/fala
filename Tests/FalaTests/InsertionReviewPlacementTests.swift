import AppKit
import XCTest
@testable import FalaCore

final class InsertionReviewPlacementTests: XCTestCase {
    func testCollapsedOriginAnchorsToBottomTrailingInsideVisibleFrame() {
        let visibleFrame = NSRect(x: 20, y: 40, width: 1280, height: 720)

        let origin = InsertionReviewPlacement.origin(
            for: InsertionReviewPlacement.collapsedSize,
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(
            origin.x,
            visibleFrame.maxX
                - InsertionReviewPlacement.collapsedSize.width
                - InsertionReviewPlacement.trailingInset
        )
        XCTAssertEqual(
            origin.y,
            visibleFrame.minY + InsertionReviewPlacement.bottomInset
        )
    }

    func testExpandedOriginKeepsBottomTrailingAnchor() {
        let visibleFrame = NSRect(x: 0, y: 0, width: 1440, height: 900)

        let origin = InsertionReviewPlacement.origin(
            for: InsertionReviewPlacement.expandedSize,
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(
            origin.x,
            visibleFrame.maxX
                - InsertionReviewPlacement.expandedSize.width
                - InsertionReviewPlacement.trailingInset
        )
        XCTAssertEqual(
            origin.y,
            visibleFrame.minY + InsertionReviewPlacement.bottomInset
        )
    }
}
