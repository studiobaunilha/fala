# GROUND-0011: Preserve the insertion review target across dismissal

**Status:** recorded
**Decision:** Reproduce the real controller action callbacks without AppKit focus side effects; if target loss is observed, capture the existing application before dismissing and pass it into the asynchronous reactivation step.
**Decision ref:** doc/tasks/0005-preserve-review-target.md
**Confidence:** Strong
**Stakes:** low × reversible

## Decision and confidence

The canonical path is to keep an action-local application reference through the asynchronous operation, independently of transient review-panel state. Swift captures local constants (A2); AppKit activates an explicit running application and may return false for a terminated/unactivatable application (A1). Matraca uses an action lifetime target lease rather than asking the current foreground window again (B1). Fala already saves the inserter and original text before clearing presentation state (C1); the same lifetime should govern its application reference. First reproduce the failure before changing action ordering. No foreground window discovery or activation is performed by tests: supply the current test process as a harmless identifier and an activation/wait closure that only records events. No GPL implementation is copied.

## Evidence

### E1 — A pending action must retain its target independently of presentation cleanup

**Tier:** Primary
**Strength:** Medium
**Provenance:** A1, A2, B1, C1, D1

Apple's activation API operates on the explicit application object; Swift capture semantics allow a constant to survive the original scope. B1 keeps application/window identity in a target lease; this supports the lifetime technique, not copying platform-specific interop. C1 captures inserter/text locally but clears the application during dismiss; D1 finds that same ordering in the release-line ancestor. This static observation is a hypothesis, not yet a reproduced defect.

### E2 — Real callback and inserter boundaries provide a bounded safe regression seam

**Tier:** Primary
**Strength:** Medium
**Provenance:** C1, C2, A2

InsertionReviewView already exposes action closures. Inject presentation into the controller's internal initializer and invoke those exact closures in tests, keeping the public initializer/default NSPanel behavior. Inject the application lookup and activation/wait operation, so tests neither show a panel nor activate an application, wait120ms or touch the system clipboard. Existing MockInserter follows TextInserting; record activation→undo/replace ordering at that real dependency boundary.

### E3 — The original controller actions lose the captured target before dispatch

**Tier:** Measurement
**Strength:** High
**Provenance:** C3

The seam-only state retained original action ordering. Six tests ran with12 assertion failures and zero unexpected failures. Both successful action fixtures reached the inserter without activation; nil/failed-activation controls also performed an operation. H1 was confirmed; H2 was falsified by a known non-nil current-process application, and H3 by the inserter completing. The fix captures the target before dismiss and requires successful reactivation before undo/replace. Final seven controller cases plus two flow and19learner cases passed:28tests/0failures,0.565seconds test execution. This is not a real focus or production UI test.

## Source register

- **A1:** https://developer.apple.com/documentation/appkit/nsrunningapplication/activate(options:).md, macOS AppKit activate(options:), signature and failure return semantics . Relevant excerpt: “Attempts to activate the application using the specified options.” (accessed 2026-11-10 via web open Markdown)
- **A2:** https://raw.githubusercontent.com/swiftlang/swift-book/main/TSPL.docc/LanguageGuide/Closures.md, Capturing Values632ff . Excerpt: “A closure can *capture* constants and variables”. (accessed 2026-11-10 via fetched official swiftlang source)
- **B1:** Matraca commit11f5434e62e3357987be0839ff33b95ff6ca3795, Matraca.Mac/Platform/MacTargetLease.cs:7–15 https://github.com/FabricioCasali/matraca/blob/11f5434e62e3357987be0839ff33b95ff6ca3795/Matraca.Mac/Platform/MacTargetLease.cs . Excerpt: `private readonly IntPtr _application;` and `_application = application;`. MIT; lifetime reference only. FluidVoice PasteDeliveryCoordinator at695eb875 was also fetched for recovery context, GPL code not copied; it is not needed to justify this narrow fix. (accessed 2026-11-10 via GitHub API tree and raw source)
- **C1:** Sources/FalaCore/UI/InsertionReviewController.swift:104–145, action-local inserter/text survive dismiss while targetApplication does not (accessed 2026-11-10 via source read at86ca327).
- **C2:** Tests/FalaTests/InsertionReviewFlowTests.swift:65 and Tests/FalaTests/DictationReplacementPipelineTests.swift:7, existing dependency injection and real inserter assertions; InsertionReviewView.swift:5–10 action callback contract (accessed 2026-11-10 via source reads).
- **D1:** `git log --oneline 86ca327 -- Sources/FalaCore/UI/InsertionReviewController.swift` returns bc7af86; source at86ca327 retains the dismiss-before-reactivation ordering. `git log --all` also returns unrelated archived checkpoints; these are not later release-line fixes. No release-line fix found (accessed 2026-11-10 via git).

- **C3:** `.agentic/reviews/insertion-target-red.log` (6tests/12assertions/0unexpected) and `insertion-target-green-final.log` (28tests/0failures), actual Swift package module with callback/inserter fakes; invocation `bash scripts/swift-env.sh test --filter InsertionReviewControllerTests` and final filter `InsertionReviewControllerTests|InsertionReviewFlowTests|CorrectionLearningAnalyzerTests`, source base86ca327 plus exact reviewed patch. Host macOS27.2.1/arm64 (accessed 2026-11-10 via executed XCTest logs)

## Plan and preregistered check

1. Preserve public init; add only internal dependencies for safe lookup, activation/wait and view presentation. Do not fix handler ordering in this seam-only change.
2. Tests call present, then the actual captured view.onUndo/onApplyEdit closures. Require activation of the captured target before the inserter operation; edited text remains trimmed and learning behavior stays unchanged. Dismiss-only must not activate. For both actions, missing target or failed/unavailable activation must skip insertion rather than editing a different foreground app. Default activation must respect AppKit Bool and verify the frontmost PID after the existing120ms wait; this is a point-in-time observation, not atomic focus ownership. Await completion through expectations, not arbitrary sleeps.
3. Observe RED on the original action ordering. Ranked falsifiable hypotheses: H1 dismiss clears the target (activation missing but undo/replace executes); H2 the target provider is nil (falsified by returning a known current-process application); H3 the asynchronous task never executes (falsified by the inserter expectation completing). Stop if the failure is not target loss.
4. If H1 is observed, capture target before dismiss and pass it explicitly to the helper, with no rediscovery or additional feature. Run the focused cases GREEN; prepare exact diff/hash for independent review. Full package gate and release changes remain with orchestration.


## Limitations and reversal

This validates controller command lifetime and dependency ordering, not real macOS focus handoff or Accessibility permission behavior. No GUI action on the running installed app, typing, deletion, clipboard mutation, model/build-version/package change or publication. If the callback tracer does not reproduce target loss, no target-order production fix is justified. Ground is written to disk ahead of the planned experiment but no git-ancestry-before-implementation claim is made.

## Audit path

Validate this record structurally, then review actual sources and RED/GREEN logs. Structural validity is not empirical reproduction.
