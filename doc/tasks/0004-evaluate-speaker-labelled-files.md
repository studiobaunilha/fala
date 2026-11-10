# Task 0004: Reconcile existing work and evaluate speaker-labelled files

**Status:** proposed
**Created:** 2026-11-10
**Scope ref:** doc/specs/0001-local-speaker-labelled-files.md
**Evidence ref:** doc/research/0008-ground-batch-and-speaker-labels.md
**Owner:** diarization evaluation role, assigned by the orchestrator
**Execution:** HITL
**Spec ref:** doc/specs/0001-local-speaker-labelled-files.md
**Board ref:**

## Context

Speaker labelling was removed from the published application, while separate local work exists around timed transcripts, speaker diarization, and timeline alignment. The next step is to assess and reuse that work where appropriate, not presume it is either complete or disposable. This is an evaluation task and does not approve implementation or rollout of the draft specification.

## Acceptance Criteria

- [ ] Existing local work is inventoried read-only and mapped to the current public base; reusable code, tests, and unresolved assumptions are documented without modifying the original checkout.
- [ ] The evaluation contract defines authorized fixtures, reference annotation, metrics, decision rule, and stop condition before the deciding run.
- [ ] Exact SDK/model licences, model download accessibility, minimum OS, and candidate speaker-count limits are checked.
- [ ] An offline candidate produces speaker-labelled, time-aligned text on a public or authorized recording, with missing assignments visible.
- [ ] Diarization error and speaker-attributed word errors are reported separately, alongside actual runtime/memory and failure cases; no universal winner is inferred from one recording.
- [ ] The recommendation states whether to continue with existing work, adapt it, or choose an alternative, with evidence supporting the disposition.

## Plan

- [ ] Reconcile the local timed-transcript/diarization work before writing any competing abstraction.
- [ ] Review and resolve the draft specification's evaluation questions, then freeze the protocol.
- [ ] Run one candidate offline first, using existing local infrastructure and retaining plain transcription as the control.
- [ ] Add an alternative only if the first candidate fails a defined criterion or an unresolved risk requires comparison.
- [ ] Deliver the evidence and a bounded production proposal; do not enable a feature or update public marketing from this evaluation alone.

## Notes

## Definition of Done

All Acceptance Criteria checked, plus:

- [ ] Local tests pass (or N/A documented in Notes)
- [ ] Code review completed (human or fresh-context reviewer per WORKFLOW §10)
- [ ] No orphan `TODO`/`FIXME` introduced
- [ ] Status updated to `done` and Notes log closes the task
