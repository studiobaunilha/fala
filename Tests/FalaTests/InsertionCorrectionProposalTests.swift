import AppKit
import XCTest
@testable import FalaCore

@MainActor
final class InsertionCorrectionProposalTests: XCTestCase {
    func testOldReviewHoverLeavesNewReviewTimeoutScheduled() throws {
        let fixture = ProposalFixture()
        fixture.present()
        let old = try XCTUnwrap(fixture.review)
        fixture.present("Nova revisão")
        let timer = try XCTUnwrap(fixture.timers.last)
        let scheduledCount = fixture.timers.count
        old.onHoverChanged(true)
        old.onHoverChanged(false)
        XCTAssertFalse(timer.isCancelled)
        XCTAssertEqual(fixture.timers.count, scheduledCount)
    }

    func testOldReviewEditingLeavesNewReviewTimeoutScheduled() throws {
        let fixture = ProposalFixture()
        fixture.present()
        let old = try XCTUnwrap(fixture.review)
        fixture.present("Nova revisão")
        let timer = try XCTUnwrap(fixture.timers.last)
        old.onEditingChanged(true)
        old.onEditingChanged(false)
        XCTAssertFalse(timer.isCancelled)
        XCTAssertEqual(fixture.timers.count, 2)
    }

    func testOldProposalHoverLeavesNewReviewTimeoutScheduled() async throws {
        let fixture = ProposalFixture()
        let old = try await applyEdit(fixture)
        fixture.present("Nova revisão")
        let timer = try XCTUnwrap(fixture.timers.last)
        let scheduledCount = fixture.timers.count
        old.onHoverChanged(true)
        old.onHoverChanged(false)
        XCTAssertFalse(timer.isCancelled)
        XCTAssertEqual(fixture.timers.count, scheduledCount)
    }

    func testNewReviewSurvivesAnOlderActionActivationFailure() async throws {
        for edit in [false, true] {
            let fixture = ProposalFixture()
            let entered = expectation(description: "old activation suspended")
            var continuation: CheckedContinuation<Bool, Never>?
            fixture.activation = {
                await withCheckedContinuation {
                    continuation = $0
                    entered.fulfill()
                }
            }
            fixture.present()
            let old = try XCTUnwrap(fixture.review)
            if edit { old.onApplyEdit("Eu comunico com Niko") } else { old.onUndo() }
            await fulfillment(of: [entered], timeout: 1)
            fixture.present("Nova revisão")
            let current = try XCTUnwrap(fixture.review)
            continuation?.resume(returning: false)
            fixture.proposed.isInverted = true
            await fulfillment(of: [fixture.proposed], timeout: 0.1)
            fixture.activation = nil
            current.onUndo()
            await fulfillment(of: [fixture.operated], timeout: 1)
            XCTAssertEqual(fixture.events, ["activate", "activate", "undo"])
        }
    }

    func testOlderUndoCompletionCannotDismissNewReview() async throws {
        let fixture = ProposalFixture()
        fixture.operated.expectedFulfillmentCount = 2
        let entered = expectation(description: "old Undo suspended")
        var continuation: CheckedContinuation<Void, Never>?
        fixture.inserter.afterUndo = {
            await withCheckedContinuation {
                continuation = $0
                entered.fulfill()
            }
        }
        fixture.present()
        try XCTUnwrap(fixture.review).onUndo()
        await fulfillment(of: [entered], timeout: 1)
        fixture.present("Nova revisão")
        let current = try XCTUnwrap(fixture.review)
        continuation?.resume()
        fixture.proposed.isInverted = true
        await fulfillment(of: [fixture.proposed], timeout: 0.1)
        fixture.inserter.afterUndo = nil
        current.onUndo()
        await fulfillment(of: [fixture.operated], timeout: 1)
        XCTAssertEqual(fixture.events, ["activate", "undo", "activate", "undo"])
    }

    func testApprovalConsumesProposalBeforeSaveCallbackCanReenter() async throws {
        let fixture = ProposalFixture()
        let proposal = try await applyEdit(fixture)
        fixture.onSave = {
            if fixture.saved.count == 1 { proposal.onApprove() }
        }
        defer { fixture.onSave = nil }
        proposal.onApprove()
        XCTAssertEqual(fixture.saved, ["Nico→Niko"])
        XCTAssertEqual(fixture.events, ["activate", "replace:Eu comunico com Niko"])
    }
}

extension InsertionCorrectionProposalTests {
    func testOnlyApprovalSavesExactPairOnceWithoutAnotherTargetOperation() async throws {
        let fixture = ProposalFixture()
        let proposal = try await applyEdit(fixture)
        XCTAssertEqual(proposal.correction.original, "Nico")
        XCTAssertEqual(proposal.correction.corrected, "Niko")
        XCTAssertTrue(fixture.saved.isEmpty)
        proposal.onApprove()
        proposal.onApprove()
        XCTAssertEqual(fixture.saved, ["Nico→Niko"])
        XCTAssertEqual(fixture.events, ["activate", "replace:Eu comunico com Niko"])
    }

    func testRejectCloseAndTimeoutDiscardWithoutReversingEdit() async throws {
        for discard in 0..<3 {
            let fixture = ProposalFixture()
            let proposal = try await applyEdit(fixture)
            switch discard {
            case 0: proposal.onReject()
            case 1: fixture.controller.dismiss()
            default: try XCTUnwrap(fixture.timers.last).perform()
            }
            proposal.onApprove()
            XCTAssertTrue(fixture.saved.isEmpty)
            XCTAssertEqual(fixture.events, ["activate", "replace:Eu comunico com Niko"])
        }
    }

    func testNewReviewInvalidatesEveryOldProposalCallbackAndTimeout() async throws {
        let fixture = ProposalFixture()
        fixture.operated.expectedFulfillmentCount = 2
        let old = try await applyEdit(fixture)
        let oldTimer = try XCTUnwrap(fixture.timers.last)
        fixture.present("Outro Nico")
        let current = try XCTUnwrap(fixture.review)
        old.onHoverChanged(true)
        old.onHoverChanged(false)
        old.onReject()
        old.onApprove()
        oldTimer.perform()
        XCTAssertTrue(fixture.saved.isEmpty)
        current.onUndo()
        await fulfillment(of: [fixture.operated], timeout: 1)
        XCTAssertEqual(fixture.events.last, "undo")
    }

    func testOldReviewCallbacksCannotAffectNewReview() async throws {
        let fixture = ProposalFixture()
        fixture.present()
        let old = try XCTUnwrap(fixture.review)
        fixture.present("Outro Nico")
        let current = try XCTUnwrap(fixture.review)
        old.onUndo()
        old.onApplyEdit("Outro Niko")
        old.onDismiss()
        old.onHoverChanged(true)
        old.onHoverChanged(false)
        old.onEditingChanged(true)
        current.onUndo()
        await fulfillment(of: [fixture.operated], timeout: 1)
        XCTAssertEqual(fixture.events, ["activate", "undo"])
        XCTAssertTrue(fixture.saved.isEmpty)
    }

    func testNewReviewDuringActivationPreventsObsoleteReplacement() async throws {
        let fixture = ProposalFixture()
        let entered = expectation(description: "activation suspended")
        var continuation: CheckedContinuation<Bool, Never>?
        fixture.activation = {
            await withCheckedContinuation {
                continuation = $0
                entered.fulfill()
            }
        }
        fixture.present()
        try XCTUnwrap(fixture.review).onApplyEdit("Eu comunico com Niko")
        await fulfillment(of: [entered], timeout: 1)
        fixture.present("Nova revisão")
        continuation?.resume(returning: true)
        fixture.operated.isInverted = true
        await fulfillment(of: [fixture.operated], timeout: 0.1)
        XCTAssertEqual(fixture.review?.insertedText, "Nova revisão")
        XCTAssertNil(fixture.proposal)
        XCTAssertTrue(fixture.saved.isEmpty)
    }

    func testNewReviewDuringReplacementCannotBeReplacedByLateProposal() async throws {
        let fixture = ProposalFixture()
        let entered = expectation(description: "replacement suspended")
        var continuation: CheckedContinuation<Void, Never>?
        fixture.inserter.afterReplacement = {
            await withCheckedContinuation {
                continuation = $0
                entered.fulfill()
            }
        }
        fixture.present()
        try XCTUnwrap(fixture.review).onApplyEdit("Eu comunico com Niko")
        await fulfillment(of: [entered], timeout: 1)
        fixture.present("Nova revisão")
        continuation?.resume()
        fixture.proposed.isInverted = true
        await fulfillment(of: [fixture.proposed], timeout: 0.1)
        XCTAssertEqual(fixture.review?.insertedText, "Nova revisão")
        XCTAssertNil(fixture.proposal)
        XCTAssertTrue(fixture.saved.isEmpty)
    }

    func testIneligibleEditsDoNotProduceProposals() async throws {
        for edit in ["Eu comunico com Nico", "Eu comunico com Nico!", "Outra frase inteiramente diferente"] {
            let fixture = ProposalFixture()
            fixture.proposed.isInverted = true
            fixture.present()
            try XCTUnwrap(fixture.review).onApplyEdit(edit)
            await fulfillment(of: [fixture.proposed], timeout: 0.1)
            XCTAssertNil(fixture.proposal)
            XCTAssertTrue(fixture.saved.isEmpty)
        }
    }

    func testDismissDuringReplacementDiscardsLateProposal() async throws {
        let fixture = ProposalFixture()
        let entered = expectation(description: "replacement suspended")
        var continuation: CheckedContinuation<Void, Never>?
        fixture.inserter.afterReplacement = {
            await withCheckedContinuation {
                continuation = $0
                entered.fulfill()
            }
        }
        fixture.present()
        try XCTUnwrap(fixture.review).onApplyEdit("Eu comunico com Niko")
        await fulfillment(of: [entered], timeout: 1)
        fixture.controller.dismiss()
        continuation?.resume()
        fixture.proposed.isInverted = true
        await fulfillment(of: [fixture.proposed], timeout: 0.1)
        XCTAssertNil(fixture.proposal)
        XCTAssertTrue(fixture.saved.isEmpty)
        XCTAssertEqual(fixture.events, ["activate", "replace:Eu comunico com Niko"])
    }

    private func applyEdit(_ fixture: ProposalFixture) async throws -> InsertionCorrectionProposalView {
        fixture.present()
        try XCTUnwrap(fixture.review).onApplyEdit("Eu comunico com Niko")
        await fulfillment(of: [fixture.proposed], timeout: 1)
        return try XCTUnwrap(fixture.proposal)
    }
}

@MainActor
private final class ProposalFixture {
    var review: InsertionReviewView?
    var proposal: InsertionCorrectionProposalView?
    var saved: [String] = []
    var events: [String] = []
    var timers: [DispatchWorkItem] = []
    var activation: (@MainActor () async -> Bool)?
    var onSave: (() -> Void)?
    let proposed = XCTestExpectation(description: "proposal presented")
    let operated = XCTestExpectation(description: "target operation")

    lazy var inserter = ProposalInserter { [unowned self] in
        events.append($0)
        operated.fulfill()
    }
    lazy var controller = InsertionReviewController(
        learnCorrection: { [unowned self] in
            saved.append($0 + "→" + $1)
            onSave?()
        },
        targetApplicationProvider: { NSRunningApplication.current },
        reactivateApplication: { [unowned self] _ in
            events.append("activate")
            return await activation?() ?? true
        },
        presentReview: { [unowned self] in review = $0 },
        presentProposal: { [unowned self] in
            proposal = $0
            proposed.fulfill()
        },
        scheduleDismissal: { [unowned self] _, timer in timers.append(timer) }
    )

    func present(_ text: String = "Eu comunico com Nico") {
        controller.present(insertedText: text, using: inserter)
    }

}

@MainActor
private final class ProposalInserter: TextInserting {
    let operation: (String) -> Void
    var afterReplacement: (@MainActor () async -> Void)?
    var afterUndo: (@MainActor () async -> Void)?

    init(operation: @escaping (String) -> Void) { self.operation = operation }
    func insert(_ text: String) async { XCTFail("Unexpected insertion") }
    func saveToClipboard(_ text: String) { XCTFail("Unexpected clipboard operation") }
    func undoLastInsertion() async {
        operation("undo")
        await afterUndo?()
    }
    func replaceLastInsertion(with text: String) async {
        operation("replace:" + text)
        await afterReplacement?()
    }
}
