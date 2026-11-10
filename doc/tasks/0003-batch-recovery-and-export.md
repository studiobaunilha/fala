# Task 0003: Verify batch recovery and exported output

**Status:** proposed
**Created:** 2026-11-10
**Scope ref:** README.md
**Evidence ref:** doc/research/0008-ground-batch-and-speaker-labels.md
**Owner:** batch delivery role, assigned by the orchestrator
**Execution:** AFK
**Spec ref:**
**Board ref:**

## Context

Batch transcription already supports a queue, per-file states, cancellation, retry, model reuse, and timing. The next slice should prove these assembled paths under real file and export failures, rather than build a second queue. This task is queued; it does not assert a reproduced defect or authorize new persistence, scheduling, or parallel execution features.

## Acceptance Criteria

- [ ] A public or authorized mixed-format queue records the actual engine/model and per-file output for each completed item.
- [ ] Cancelling a run retains completed outputs and identifies unfinished items; retry processes retryable items without reprocessing completed items.
- [ ] An unreadable input and unwritable output produce observable item failures rather than a successful completion claim.
- [ ] Files with the same basename from different directories produce distinct outputs or an explicit conflict outcome, with no silent overwrite.
- [ ] The final report names any reproduced failures and their fixtures; production changes are limited to those proven failures.
- [ ] Audio-preparation, model-preparation, transcription, and saving timings are captured as observations, without invented pass/fail speed thresholds.

## Plan

- [ ] Start after the selected-model and correction slices are integrated; freeze fixtures and expected state transitions before execution.
- [ ] Review existing queue tests and any local work in progress; retain the existing implementation unless a reproduced failure requires a change.
- [ ] Run the assembled GUI/CLI paths on local public or authorized files; reproduce each failure before proposing a fix.
- [ ] For each proven failure, add one regression through the public behavior, implement the smallest correction, and rerun the affected path.
- [ ] Obtain review for any code delta and retain per-file results and exact code state.

## Notes

## Definition of Done

All Acceptance Criteria checked, plus:

- [ ] Local tests pass (or N/A documented in Notes)
- [ ] Code review completed (human or fresh-context reviewer per WORKFLOW §10)
- [ ] No orphan `TODO`/`FIXME` introduced
- [ ] Status updated to `done` and Notes log closes the task
