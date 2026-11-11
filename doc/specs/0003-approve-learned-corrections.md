# Spec 0003: Approve a learned correction before saving

**Status:** draft
**Created:** 2026-11-10
**Owner:** correction approval delivery role

## Context

A one-time edit should not silently become a permanent rule. Fala already extracts a bounded correction after an insertion-review edit; this slice separates applying the edit from authorizing reusable learning. It preserves the owner's manual replacement tools and the corrected text itself.

## User Scenarios

- Given an inserted result, when the user edits a reusable name correction, then that edit applies immediately and a local original → replacement proposal appears without saving a rule.
- Given a proposal, when Approve is chosen, then the existing rule-upsert callback runs exactly once and the proposal closes.
- Given a proposal, when Reject/close/timeout/new review occurs, then no rule is saved and the applied edit remains.
- Given failed target activation, Undo, unchanged text, punctuation-only or unrelated edits, when review finishes, then no proposal or learned rule is produced.

## Requirements

### Functional

- R1: Retain `CorrectionLearningAnalyzer` eligibility and whole-term reproduction checks. Do not add broader detection or external observation.
- R2: After the existing successful activation and edit path, store at most one proposal in memory and present the exact original/corrected pair with Approve and Reject. Label it as a global replacement rule: approval affects future text in every vocabulary context. Do not imply context-exclusive learning or persist raw snippets/pending proposals.
- R3: Only explicit Approve invokes `learnCorrection(original, corrected)`. Consume the proposal before invoking the callback so repeated/stale callbacks cannot save twice. Reject, dismissal and replacement by a newer review are nonlearning outcomes.
- R4: A late async edit completion cannot replace a newer review with an obsolete proposal; scope all callbacks, including edit/Undo/dismiss/hover, to the current review identity and revalidate after suspension. Approval must neither reactivate nor edit the target again. Preserve task0005's captured-target failure behavior.
- R5: Existing manual add/remove rules remain unchanged, immediately persistent through their existing controls. Existing saved rules continue applying; learned rules remain global, distinct from the vocabulary context selected during dictation.
- R6: No AI call, contact lookup or audio storage. No automatic-save fallback is permitted. If rollout gating disables proposal UI, discard the learning candidate rather than save it silently.

### Non-functional

Use native localized buttons and an accessible readable pair. Avoid logging the snippets or promising proof of actual field replacement: `TextInserting` currently has no result acknowledgement.

## Success Criteria

- Callback tests prove zero persistence before approval, exactly one persistence on approval, zero on every discard path, and preserved manual edits.
- Current target success/failure/Undo tests and analyzer/Nico boundary regressions pass.
- A newer review supersedes a stale completion and stale Approve closure harmlessly.
- Assembled review UI visibly distinguishes applying an edit from saving a reusable rule.

## Edge Cases

Duplicate rule approval uses current idempotent upsert. Empty edited text keeps the current disabled-apply control. Proposal state expires with its review lifecycle and does not survive relaunch. Dismissal may use an existing panel timeout, but timeout always means discard.

## Out of Scope

Learning from edits in external applications, AI review, persistent proposal inbox, repetition thresholds, per-profile replacements or changed correction extraction.

## Open Questions

None blocking. Callback-based target editing remains best effort; no new claim of guaranteed insertion is made.

## Related

- Evidence: `doc/research/0017-ground-manual-personalization.md`
- Evaluation: `doc/research/0018-prism-personalization-save.md`
- Task: `doc/tasks/0007-approve-learned-corrections.md`
- Depends on preserved behavior from `doc/tasks/0005-preserve-review-target.md`
