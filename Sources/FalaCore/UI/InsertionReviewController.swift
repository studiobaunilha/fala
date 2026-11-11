import AppKit
import SwiftUI

private final class InsertionReviewPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
public final class InsertionReviewController: InsertionReviewPresenting {
    private let analyzer = CorrectionLearningAnalyzer()
    private let learnCorrection: (String, String) -> Void
    private let targetApplicationProvider: () -> NSRunningApplication?
    private let reactivateApplication: (NSRunningApplication) async -> Bool
    private let presentReview: ((InsertionReviewView) -> Void)?
    private let presentProposal: ((InsertionCorrectionProposalView) -> Void)?
    private let scheduleDismissal: ((TimeInterval, DispatchWorkItem) -> Void)?

    private var panel: NSPanel?
    private var dismissWorkItem: DispatchWorkItem?
    private var targetApplication: NSRunningApplication?
    private var currentInsertedText = ""
    private var currentInserter: (any TextInserting)?
    private var reviewID: UUID?
    private var pendingCorrection: CorrectionLearningAnalyzer.LearnedCorrection?

    public convenience init(learnCorrection: @escaping (String, String) -> Void) {
        self.init(
            learnCorrection: learnCorrection,
            targetApplicationProvider: { NSWorkspace.shared.frontmostApplication },
            reactivateApplication: { application in
                let activated = application.activate(options: [])
                try? await Task.sleep(nanoseconds: 120_000_000)
                return activated
                    && NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier
            },
            presentReview: nil
        )
    }

    init(
        learnCorrection: @escaping (String, String) -> Void,
        targetApplicationProvider: @escaping () -> NSRunningApplication?,
        reactivateApplication: @escaping (NSRunningApplication) async -> Bool,
        presentReview: ((InsertionReviewView) -> Void)?,
        presentProposal: ((InsertionCorrectionProposalView) -> Void)? = nil,
        scheduleDismissal: ((TimeInterval, DispatchWorkItem) -> Void)? = nil
    ) {
        self.learnCorrection = learnCorrection
        self.targetApplicationProvider = targetApplicationProvider
        self.reactivateApplication = reactivateApplication
        self.presentReview = presentReview
        self.presentProposal = presentProposal
        self.scheduleDismissal = scheduleDismissal
    }

    public func present(insertedText: String, using inserter: any TextInserting) {
        let trimmedText = insertedText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmedText.isEmpty else { return }

        dismiss()
        let id = UUID()
        reviewID = id

        currentInsertedText = trimmedText
        currentInserter = inserter
        targetApplication = targetApplicationProvider()

        let review = InsertionReviewView(
                insertedText: trimmedText,
                onUndo: { [weak self] in
            guard self?.reviewID == id else { return }
            self?.handleUndo()
                },
                onApplyEdit: { [weak self] editedText in
            guard self?.reviewID == id else { return }
            self?.handleApplyEdit(editedText)
                },
                onDismiss: { [weak self] in
            guard self?.reviewID == id else { return }
            self?.dismiss()
                },
                onHoverChanged: { [weak self] hovering in
            guard self?.reviewID == id else { return }
            self?.handleHoverChanged(hovering)
                },
                onEditingChanged: { [weak self] editing in
            guard self?.reviewID == id else { return }
            self?.handleEditingChanged(editing)
                }
        )
        if let presentReview {
            presentReview(review)
        } else {
            let panel = makePanel()
            panel.contentView = NSHostingView(rootView: review)
            position(panel: panel, size: InsertionReviewPlacement.collapsedSize)
            self.panel = panel
            panel.orderFrontRegardless()
        }
        if reviewID == id { scheduleDismiss(after: 6.0) }
    }

    public func dismiss() {
        reviewID = nil
        pendingCorrection = nil
        hidePanel()
        currentInsertedText = ""
        currentInserter = nil
        targetApplication = nil
    }

    private func hidePanel() {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
        panel?.orderOut(nil)
        panel = nil
    }

    private func handleHoverChanged(_ hovering: Bool) {
        if hovering {
            dismissWorkItem?.cancel()
            dismissWorkItem = nil
        } else {
            scheduleDismiss(after: 2.5)
        }
    }

    private func handleEditingChanged(_ editing: Bool) {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil

        guard let panel else { return }
        let targetSize = editing
            ? InsertionReviewPlacement.expandedSize
            : InsertionReviewPlacement.collapsedSize
        if editing {
            panel.makeKeyAndOrderFront(nil)
        }
        position(panel: panel, size: targetSize, animate: true)

        if !editing {
            scheduleDismiss(after: 2.5)
        }
    }

}

extension InsertionReviewController {
    private func handleUndo() {
        guard let inserter = currentInserter else {
            dismiss()
            return
        }

        let targetApplication = targetApplication
        dismiss()
        let id = UUID()
        reviewID = id

        Task { @MainActor in
            guard reviewID == id else { return }
            guard await reactivateTargetApplication(targetApplication), reviewID == id else {
                if reviewID == id { dismiss() }
                return
            }
            await inserter.undoLastInsertion()
            if reviewID == id { dismiss() }
        }
    }

    private func handleApplyEdit(_ editedText: String) {
        guard let inserter = currentInserter else {
            dismiss()
            return
        }

        let originalText = currentInsertedText
        let trimmedEditedText = editedText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let targetApplication = targetApplication
        dismiss()
        let id = UUID()
        reviewID = id

        Task { @MainActor in
            guard reviewID == id else { return }
            guard await reactivateTargetApplication(targetApplication), reviewID == id else {
                if reviewID == id { dismiss() }
                return
            }
            await inserter.replaceLastInsertion(with: trimmedEditedText)
            guard reviewID == id else { return }

            if let learned = analyzer.learnedCorrection(
                from: originalText,
                to: trimmedEditedText,
                insertedText: originalText
            ) {
                showProposal(learned, id: id)
            } else {
                dismiss()
            }
        }
    }

    private func showProposal(_ correction: CorrectionLearningAnalyzer.LearnedCorrection, id: UUID) {
        pendingCorrection = correction
        let proposal = InsertionCorrectionProposalView(
            correction: correction,
            onApprove: { [weak self] in
                guard let self, self.reviewID == id, let pending = self.pendingCorrection else { return }
                self.dismiss()
                self.learnCorrection(pending.original, pending.corrected)
            },
            onReject: { [weak self] in
                guard self?.reviewID == id else { return }
                self?.dismiss()
            },
            onHoverChanged: { [weak self] hovering in
                guard self?.reviewID == id else { return }
                self?.handleHoverChanged(hovering)
            }
        )
        if let presentProposal {
            presentProposal(proposal)
        } else {
            let panel = makePanel()
            panel.contentView = NSHostingView(rootView: proposal)
            position(panel: panel, size: InsertionReviewPlacement.proposalSize)
            self.panel = panel
            panel.makeKeyAndOrderFront(nil)
        }
        if reviewID == id { scheduleDismiss(after: 12.0) }
    }

    private func reactivateTargetApplication(_ targetApplication: NSRunningApplication?) async -> Bool {
        guard let targetApplication else { return false }
        return await reactivateApplication(targetApplication)
    }

    private func scheduleDismiss(after seconds: TimeInterval) {
        dismissWorkItem?.cancel()
        let id = reviewID
        let workItem = DispatchWorkItem { [weak self] in
            guard self?.reviewID == id else { return }
            self?.dismiss()
        }
        dismissWorkItem = workItem
        if let scheduleDismissal {
            scheduleDismissal(seconds, workItem)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: workItem)
        }
    }

    private func makePanel() -> NSPanel {
        let panel = InsertionReviewPanel(
            contentRect: NSRect(
                origin: .zero,
                size: InsertionReviewPlacement.collapsedSize
            ),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        return panel
    }

    private func position(
        panel: NSPanel,
        size: NSSize,
        animate: Bool = false
    ) {
        let mouseLocation = NSEvent.mouseLocation
        let visibleFrame = InsertionReviewPlacement.screen(
            containing: mouseLocation
        )?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let origin = InsertionReviewPlacement.origin(
            for: size,
            visibleFrame: visibleFrame
        )
        let frame = NSRect(origin: origin, size: size)
        panel.setFrame(frame, display: true, animate: animate)
    }
}
