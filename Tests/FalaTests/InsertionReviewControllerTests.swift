import AppKit
import XCTest
@testable import FalaCore

@MainActor
final class InsertionReviewControllerTests: XCTestCase {
    func testUndoReactivatesCapturedTargetBeforeUndo() async throws {
        try await checkAction(edit: false, targetAvailable: true, activationSucceeds: true)
    }

    func testEditReactivatesCapturedTargetBeforeReplacingAndLearning() async throws {
        try await checkAction(edit: true, targetAvailable: true, activationSucceeds: true)
    }

    func testUndoDoesNothingWithoutTarget() async throws {
        try await checkAction(edit: false, targetAvailable: false, activationSucceeds: true)
    }

    func testEditDoesNothingWithoutTarget() async throws {
        try await checkAction(edit: true, targetAvailable: false, activationSucceeds: true)
    }

    func testUndoDoesNothingWhenActivationFails() async throws {
        try await checkAction(edit: false, targetAvailable: true, activationSucceeds: false)
    }

    func testEditDoesNothingWhenActivationFails() async throws {
        try await checkAction(edit: true, targetAvailable: true, activationSucceeds: false)
    }

    func testDismissDoesNotReactivateOrEdit() async throws {
        try await checkAction(edit: false, targetAvailable: true, activationSucceeds: true, dismissOnly: true)
    }

    private func checkAction(
        edit: Bool, targetAvailable: Bool, activationSucceeds: Bool, dismissOnly: Bool = false
    ) async throws {
        let operation = expectation(description: "inserter operation")
        let shouldOperate = targetAvailable && activationSucceeds && !dismissOnly
        operation.isInverted = !shouldOperate
        let application = NSRunningApplication.current
        var events: [String] = []
        var view: InsertionReviewView?
        var learned: [String] = []
        let inserter = ReviewActionInserter { event in
            events.append(event)
            operation.fulfill()
        }
        let controller = InsertionReviewController(
            learnCorrection: { original, corrected in learned.append(original + "→" + corrected) },
            targetApplicationProvider: { targetAvailable ? application : nil },
            reactivateApplication: { target in
                XCTAssertEqual(target.processIdentifier, application.processIdentifier)
                events.append("activate")
                return activationSucceeds
            },
            presentReview: { view = $0 }
        )
        defer { controller.dismiss() }
        controller.present(insertedText: "Eu comunico com Nico", using: inserter)
        let review = try XCTUnwrap(view)
        if dismissOnly {
            review.onDismiss()
        } else if edit {
            review.onApplyEdit("  Eu comunico com Niko  ")
        } else {
            review.onUndo()
        }
        await fulfillment(of: [operation], timeout: shouldOperate ? 1 : 0.1)
        if shouldOperate {
            XCTAssertEqual(events, ["activate", edit ? "replace:Eu comunico com Niko" : "undo"])
            XCTAssertEqual(learned, edit ? ["Nico→Niko"] : [])
        } else {
            XCTAssertEqual(events, targetAvailable && !dismissOnly ? ["activate"] : [])
            XCTAssertTrue(learned.isEmpty)
        }
    }
}

@MainActor
private final class ReviewActionInserter: TextInserting {
    private let operation: (String) -> Void

    init(operation: @escaping (String) -> Void) { self.operation = operation }
    func insert(_ text: String) async { XCTFail("Unexpected insertion") }
    func saveToClipboard(_ text: String) { XCTFail("Unexpected clipboard operation") }
    func undoLastInsertion() async { operation("undo") }
    func replaceLastInsertion(with text: String) async { operation("replace:" + text) }
}
