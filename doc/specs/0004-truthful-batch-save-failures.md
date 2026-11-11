# Spec 0004: Report batch save failures truthfully

**Status:** draft
**Created:** 2026-11-10
**Owner:** batch save delivery role

## Context

A transcript that was generated but not saved must not appear as a completed export. Existing task0003 owns broad batch recovery; this delivery isolates ignored write errors and recoverable results without building a new queue or export system.

## User Scenarios

- Given a valid transcribed item and failing output write, when final saving fails, then the item visibly fails, explains the save problem and never advertises a completed file.
- Given a queue with one save failure and another successful item, when it finishes, then statuses and aggregate feedback preserve the failure and the successful file remains usable.
- Given a retained complete result after save failure, when the user selects a writable destination and retries, then saving can recover without generating a false earlier success or losing the retained text.

## Requirements

### Functional

- R1: Reproduce ignored append/final overwrite errors before changes. Propagate write/open/seek/close failures to the real item outcome. Never record success before required writes finish successfully.
- R2: Keep a completed generated transcript available in memory after final save failure and expose a bounded recover/copy or retry-save path through existing batch UI. Prefer retry-save without rerunning transcription when complete content exists. Partial streaming content must be identified as incomplete, never promoted to a complete result.
- R3: Retry respects the current output directory/name policy and preserves other completed items. Existing cancellation and same-basename reservation behavior remains; cancellation is not success.
- R4: CLI save errors return its existing failure exit behavior; do not regress its checked final write. Text/Markdown output semantics remain unchanged.
- R5: Raw file-system details may support diagnostics, but visible status must explain that transcription output was not saved. Do not silently overwrite another queue item's output or treat a partial artifact as completion.

### Non-functional

No persistent transcript library or new dependency. Use existing queue, item states, retry/output controls and timing seams; retain content only for the live job. No fabricated throughput criterion.

## Success Criteria

- Injected or deterministic real write failures exercise initialization, append and final overwrite; each produces failure, no completed path, and no false save success.
- A mixed queue preserves independent item statuses; recovered saving writes the retained expected contents once and does not redo a completed model/LLM operation when the retry-save path is used.
- Cancellation, successful save and filename-collision regressions pass. Run an assembled writable-success/unwritable-failure/recovery check on a public or authorized input.

## Edge Cases

Failure after a partial file, missing parent directory, an output path occupied by a directory, user cancellation during processing, and one successful item before/after a failed item. Use deterministic failure fixtures, not chmod alone under privileged execution.

## Out of Scope

Other task0003 criteria are not automatically completed: mixed-codec survey, persistent jobs, parallel execution, new timed/SRT/JSON exports, diarization and audio retention remain outside this slice.

## Open Questions

None blocking. Delivery must record which existing recovery seam was reused and whether partial text is separately exposed.

## Related

- Parent task: `doc/tasks/0003-batch-recovery-and-export.md` remains separately open
- Delivery task: `doc/tasks/0008-truthful-batch-save-failures.md`
- Evaluation: `doc/research/0018-prism-personalization-save.md`
- Save-worker four-source receipt: reserved `doc/research/0020-ground-batch-save.md` (worker chooses exact slug)
