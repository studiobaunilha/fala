import XCTest
import SwiftUI
@testable import FalaCore

final class WindowFactoryTests: XCTestCase {

    override func setUp() async throws {
        await MainActor.run { AnimationConfig.enabled = false }
    }

    @MainActor
    func testWindowFactoryAppliesConfig() {
        let config = WindowConfig(title: "Test", width: 100, height: 100)
        let window = WindowFactory.makeWindow(config: config, content: Text("Test"))

        XCTAssertEqual(window.title, "Test")
        XCTAssertEqual(window.styleMask.contains(.titled), true)
        XCTAssertEqual(window.styleMask.contains(.closable), true)
        XCTAssertNil(window.appearance)
        XCTAssertFalse(window.isReleasedWhenClosed)
    }

    @MainActor
    func testWindowFactoryAppliesExplicitAppearance() {
        let config = WindowConfig(
            title: "Test",
            width: 100,
            height: 100,
            appearance: NSAppearance(named: .darkAqua)
        )
        let window = WindowFactory.makeWindow(config: config, content: Text("Test"))

        XCTAssertEqual(window.appearance?.name, .darkAqua)
    }

    @MainActor
    func testWindowFactoryResizable() {
        let config = WindowConfig(title: "Test", width: 100, height: 100, isResizable: true)
        let window = WindowFactory.makeWindow(config: config, content: Text("Test"))

        XCTAssertEqual(window.styleMask.contains(.resizable), true)
    }

    @MainActor
    func testWindowFactoryMinSize() {
        let minSize = NSSize(width: 50, height: 50)
        let config = WindowConfig(title: "Test", width: 100, height: 100, minSize: minSize)
        let window = WindowFactory.makeWindow(config: config, content: Text("Test"))

        XCTAssertEqual(window.minSize, minSize)
    }

    @MainActor
    func testWindowFactoryAppliesFullSizeSidebarChrome() {
        let config = WindowConfig(
            title: "Test",
            width: 100,
            height: 100,
            fullSizeContentView: true,
            transparentTitlebar: true
        )
        let window = WindowFactory.makeWindow(config: config, content: Text("Test"))

        XCTAssertTrue(window.styleMask.contains(.fullSizeContentView))
        XCTAssertTrue(window.titlebarAppearsTransparent)
        XCTAssertEqual(window.titleVisibility, .hidden)
    }
}
