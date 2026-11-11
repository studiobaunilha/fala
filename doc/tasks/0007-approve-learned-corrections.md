# Task 0007: Require approval before saving learned corrections

**Status:** planned
**Created:** 2026-11-10
**Owner:** correction approval delivery role
**Execution:** AFK
**Spec ref:** doc/specs/0003-approve-learned-corrections.md
**Evidence ref:** doc/research/0017-ground-manual-personalization.md
**Evaluation ref:** doc/research/0018-prism-personalization-save.md

## Context

Keep applying review edits, but stop silently turning a correction into a permanent rule. Owner authorization covers this bounded delivery; source baseline `3ba31a7`. Reuse the current analyzer and callback rather than another learning system.

## Acceptance Criteria

- [ ] Spec0003 R1–R6 and its success criteria pass.
- [ ] No persistent callback occurs before explicit approval; approval is idempotent.
- [ ] Reject/timeout/dismiss/new review/stale callback paths never learn or undo the applied edit.
- [ ] Successful/failed target activation, Undo, manual rule tools and analyzer regressions remain intact.

## Plan

- [ ] Write callback-level RED tests for proposal-before-save and approve/reject lifecycle through the real controller and fake presentation.
- [ ] Add one in-memory pending proposal and review identity; present original → corrected with native Approve/Reject.
- [ ] Consume before persistence, invalidate on dismissal/new session, prevent stale async completion from replacing a newer review.
- [ ] Verify current insertion/learning tests plus new cases; run assembled proposal UI and independent review.

## Ownership and integration contract

Worker C owns `UI/InsertionReviewController.swift`, `UI/InsertionReviewView.swift`, `UI/InsertionReviewPlacement.swift` if necessary, a new proposal value/view if appropriate, `Tests/FalaTests/InsertionReviewControllerTests.swift` and proposal-specific tests. No changes to AppConfig, AppSettings, AppDelegate, batch files, context profiles, analyzer extraction or replacement algorithm. Request localization additions from root/contexts owner to avoid competing edits to shared resources, or use unique namespaced keys in a separately coordinated patch.

Keep public `InsertionReviewController(learnCorrection:)` and its internal injected dependency initializer source-compatible. The existing callback signature `(String, String) -> Void` remains; only its invocation moves behind Approve. Tests/UI can receive proposal callbacks through a new optional presentation seam. `dismiss()` invalidates pending proposal and callback identity; a separate internal hide-panel method can preserve local state only when explicitly transitioning from edit to proposal. Preserve task0005's captured target before dismissal. If feature gating is required, disabled means no automatic learning, not legacy autosave.

## Notes

- 2026-11-10 — Risk register: save before approval (Conditional, callback spy proves zero before Approve); async stale completion hijacks new review (Conditional, two-generation callback test); cancellation resets a candidate too soon or saves twice (Conditional, lifecycle/idempotency tests); focus regression (Conditional, reuse task0005 controller tests plus native smoke); manual rule APIs changed accidentally (Strong, excluded ownership). No new model/provider uncertainty remains. The contract and execution receipts are recorded alongside this delivery.

## Definition of Done

- [ ] Tests/gates and native proposal check retained with SHA.
- [ ] Fresh-context review covers new persistence boundary and stale callbacks.
- [ ] Source delta and limitations handed to release owner; no publish by this worker.
