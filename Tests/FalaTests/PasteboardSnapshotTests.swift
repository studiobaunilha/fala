import AppKit
import XCTest
@testable import FalaCore

@MainActor
final class PasteboardSnapshotTests: XCTestCase {
    func testRestoreRecoversCustomPasteboardRepresentation() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("PasteboardSnapshotTests.\(UUID().uuidString)"))
        let customType = NSPasteboard.PasteboardType("dev.fala.test.custom")

        pasteboard.clearContents()
        let originalItem = NSPasteboardItem()
        originalItem.setString("Texto original", forType: .string)
        originalItem.setData(Data([0xCA, 0xFE]), forType: customType)
        XCTAssertTrue(pasteboard.writeObjects([originalItem]))

        let snapshot = PasteboardSnapshot.capture(from: pasteboard)

        pasteboard.clearContents()
        let replacementItem = NSPasteboardItem()
        replacementItem.setString("Substituido", forType: .string)
        XCTAssertTrue(pasteboard.writeObjects([replacementItem]))

        snapshot.restore(to: pasteboard)

        let restoredItem = try XCTUnwrap(pasteboard.pasteboardItems?.first)
        XCTAssertEqual(restoredItem.string(forType: .string), "Texto original")
        XCTAssertEqual(restoredItem.data(forType: customType), Data([0xCA, 0xFE]))
    }

    func testRestoreRecoversMultipleItemsAndRepresentations() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("PasteboardSnapshotTests.Multi.\(UUID().uuidString)"))
        let customType = NSPasteboard.PasteboardType("dev.fala.test.metadata")

        pasteboard.clearContents()

        let firstItem = NSPasteboardItem()
        firstItem.setString("Primeiro", forType: .string)
        firstItem.setString("file:///tmp/primeiro.txt", forType: .fileURL)

        let secondItem = NSPasteboardItem()
        secondItem.setString("Segundo", forType: .string)
        secondItem.setData(Data("meta".utf8), forType: customType)

        XCTAssertTrue(pasteboard.writeObjects([firstItem, secondItem]))

        let snapshot = PasteboardSnapshot.capture(from: pasteboard)

        pasteboard.clearContents()
        pasteboard.setString("Temporario", forType: .string)

        snapshot.restore(to: pasteboard)

        let restoredItems = try XCTUnwrap(pasteboard.pasteboardItems)
        XCTAssertEqual(restoredItems.count, 2)
        XCTAssertEqual(restoredItems[0].string(forType: .string), "Primeiro")
        XCTAssertEqual(restoredItems[0].string(forType: .fileURL), "file:///tmp/primeiro.txt")
        XCTAssertEqual(restoredItems[1].string(forType: .string), "Segundo")
        XCTAssertEqual(restoredItems[1].data(forType: customType), Data("meta".utf8))
    }
}
