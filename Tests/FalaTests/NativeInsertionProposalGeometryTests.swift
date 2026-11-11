import AppKit
import SwiftUI
import XCTest
@testable import FalaCore

@MainActor
final class NativeInsertionProposalGeometryTests: XCTestCase {
    func testRealControllerPanelsInEveryLanguage() async throws {
        guard ProcessInfo.processInfo.environment["FALA_NATIVE_UI_SMOKE"] == "1" else {
            throw XCTSkip("Set FALA_NATIVE_UI_SMOKE=1 in the protected native UI runner.")
        }
        _ = NSApplication.shared
        let initialFrontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier
        defer {
            XCTAssertEqual(NSWorkspace.shared.frontmostApplication?.processIdentifier, initialFrontmost,
                           "The nonactivating smoke must not take application focus")
        }
        let output = URL(fileURLWithPath: try XCTUnwrap(
            ProcessInfo.processInfo.environment["FALA_NATIVE_UI_OUTPUT"]
        ))
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        defer { AppLocalization.apply(languageCode: "auto") }
        for (index, language) in AppLocalization.supportedAppLanguageCodes.enumerated() {
            try await exerciseProposal(language: language, index: index, output: output)
        }
    }

    private func exerciseProposal(language: String, index: Int, output: URL) async throws {
        AppLocalization.apply(languageCode: language)
        var saved: [String] = []
        let inserter = NativeSmokeInserter()
        let applied = expectation(description: "edit requested")
        inserter.didReplace = { applied.fulfill() }
        let controller = InsertionReviewController(
            learnCorrection: { saved.append($0 + "→" + $1) },
            targetApplicationProvider: { NSRunningApplication.current },
            reactivateApplication: { _ in true },
            presentReview: nil
        )
        controller.present(insertedText: "Eu comunico com Nico", using: inserter)
        let reviewHost = try XCTUnwrap(NSApp.windows.compactMap {
            $0.contentView as? NSHostingView<InsertionReviewView>
        }.first(where: { $0.window?.isVisible == true }))
        XCTAssertTrue(try XCTUnwrap(reviewHost.window).styleMask.contains(.nonactivatingPanel))
        try capture(reviewHost, to: output.appendingPathComponent("\(language)-review.png"))
        reviewHost.rootView.onApplyEdit("Eu comunico com Niko")
        await fulfillment(of: [applied], timeout: 1)
        let proposalHost = try XCTUnwrap(NSApp.windows.compactMap {
            $0.contentView as? NSHostingView<InsertionCorrectionProposalView>
        }.first(where: { $0.window?.isVisible == true }))
        XCTAssertTrue(try XCTUnwrap(proposalHost.window).styleMask.contains(.nonactivatingPanel))
        let window = try XCTUnwrap(proposalHost.window)
        print("[NativeUI] language=\(language) proposalFrame=\(window.frame)")
        XCTAssertTrue(NSScreen.screens.contains { $0.visibleFrame.contains(window.frame) })
        XCTAssertEqual(window.frame.size, InsertionReviewPlacement.proposalSize)
        XCTAssertEqual(proposalHost.bounds.size, InsertionReviewPlacement.proposalSize)
        XCTAssertEqual(proposalHost.rootView.correction.original, "Nico")
        XCTAssertTrue(saved.isEmpty)
        try capture(proposalHost, to: output.appendingPathComponent("\(language)-proposal.png"))
        verifyDecision(index: index, proposal: proposalHost.rootView, controller: controller, saved: { saved })
        XCTAssertEqual(inserter.replacements, ["Eu comunico com Niko"])
        controller.dismiss()
    }

    private func verifyDecision(
        index: Int, proposal: InsertionCorrectionProposalView,
        controller: InsertionReviewController, saved: () -> [String]
    ) {
        if index == 0 {
            proposal.onApprove()
            proposal.onApprove()
            XCTAssertEqual(saved(), ["Nico→Niko"])
        } else if index == 1 {
            proposal.onReject()
            proposal.onApprove()
            XCTAssertTrue(saved().isEmpty)
        } else {
            controller.dismiss()
            proposal.onApprove()
            XCTAssertTrue(saved().isEmpty)
        }
    }

    private func capture(_ view: NSView, to url: URL) throws {
        view.layoutSubtreeIfNeeded()
        view.displayIfNeeded()
        let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try data.write(to: url)
    }
}

@MainActor
private final class NativeSmokeInserter: TextInserting {
    var replacements: [String] = []
    var didReplace: (() -> Void)?
    func insert(_ text: String) async { XCTFail("Unexpected insert") }
    func saveToClipboard(_ text: String) { XCTFail("Unexpected clipboard") }
    func undoLastInsertion() async { XCTFail("Unexpected undo") }
    func replaceLastInsertion(with text: String) async {
        replacements.append(text)
        didReplace?()
    }
}
