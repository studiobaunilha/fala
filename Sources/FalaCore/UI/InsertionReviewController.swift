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

    private var panel: NSPanel?
    private var dismissWorkItem: DispatchWorkItem?
    private var targetApplication: NSRunningApplication?
    private var currentInsertedText = ""
    private var currentInserter: (any TextInserting)?

    public init(learnCorrection: @escaping (String, String) -> Void) {
        self.learnCorrection = learnCorrection
    }

    public func present(insertedText: String, using inserter: any TextInserting) {
        let trimmedText = insertedText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmedText.isEmpty else { return }

        dismiss()

        currentInsertedText = trimmedText
        currentInserter = inserter
        targetApplication = NSWorkspace.shared.frontmostApplication

        let panel = makePanel()
        panel.contentView = NSHostingView(
            rootView: InsertionReviewView(
                insertedText: trimmedText,
                onUndo: { [weak self] in
                    self?.handleUndo()
                },
                onApplyEdit: { [weak self] editedText in
                    self?.handleApplyEdit(editedText)
                },
                onDismiss: { [weak self] in
                    self?.dismiss()
                },
                onHoverChanged: { [weak self] hovering in
                    self?.handleHoverChanged(hovering)
                },
                onEditingChanged: { [weak self] editing in
                    self?.handleEditingChanged(editing)
                }
            )
        )
        position(panel: panel, size: InsertionReviewPlacement.collapsedSize)
        self.panel = panel
        panel.orderFrontRegardless()

        scheduleDismiss(after: 6.0)
    }

    public func dismiss() {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
        panel?.orderOut(nil)
        panel = nil
        currentInsertedText = ""
        currentInserter = nil
        targetApplication = nil
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

    private func handleUndo() {
        guard let inserter = currentInserter else {
            dismiss()
            return
        }

        dismiss()

        Task { @MainActor in
            await reactivateTargetApplication()
            await inserter.undoLastInsertion()
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

        dismiss()

        Task { @MainActor in
            await reactivateTargetApplication()
            await inserter.replaceLastInsertion(with: trimmedEditedText)

            if let learned = analyzer.learnedCorrection(
                from: originalText,
                to: trimmedEditedText,
                insertedText: originalText
            ) {
                learnCorrection(learned.original, learned.corrected)
            }
        }
    }

    private func reactivateTargetApplication() async {
        guard let targetApplication else { return }
        targetApplication.activate(options: [])
        try? await Task.sleep(nanoseconds: 120_000_000)
    }

    private func scheduleDismiss(after seconds: TimeInterval) {
        dismissWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.dismiss()
        }
        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + seconds,
            execute: workItem
        )
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
