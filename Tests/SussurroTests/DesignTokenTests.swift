import XCTest
import SwiftUI
@testable import SussurroCore

final class DesignTokenTests: XCTestCase {

    func testSpacingScaleIsMonotonic() {
        XCTAssertTrue(Spacing.xxs < Spacing.xs)
        XCTAssertTrue(Spacing.xs < Spacing.sm)
        XCTAssertTrue(Spacing.sm < Spacing.md)
        XCTAssertTrue(Spacing.md < Spacing.lg)
        XCTAssertTrue(Spacing.lg < Spacing.xl)
        XCTAssertTrue(Spacing.xl < Spacing.xxl)
    }

    @MainActor
    func testAnimationConfigDisablesAnimations() {
        AnimationConfig.enabled = false
        XCTAssertNil(AnimationConfig.standard)
        XCTAssertNil(AnimationConfig.spring)

        AnimationConfig.enabled = true
        XCTAssertNotNil(AnimationConfig.standard)
        XCTAssertNotNil(AnimationConfig.spring)
    }
}
