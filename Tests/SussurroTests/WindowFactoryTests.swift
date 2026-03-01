import XCTest
import SwiftUI
@testable import SussurroCore

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
        XCTAssertEqual(window.appearance?.name, .darkAqua)
        XCTAssertFalse(window.isReleasedWhenClosed)
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
}
