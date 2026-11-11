# Task 0008: Deliver truthful batch save failure and recovery

**Status:** in-progress
**Created:** 2026-11-10
**Owner:** batch save delivery role
**Execution:** AFK
**Spec ref:** doc/specs/0004-truthful-batch-save-failures.md
**Scope ref:** doc/tasks/0003-batch-recovery-and-export.md
**Evidence ref:** doc/research/0020-ground-batch-save-recovery.md
**Evaluation ref:** doc/research/0018-prism-personalization-save.md

## Context

This is the bounded save-result portion of task0003, not completion of its full batch scope. Baseline `3ba31a7`; owner authorization covers delivery and release. Reproduce actual ignored write failures, then retain the generated result and offer truthful recovery.

## Acceptance Criteria

- [ ] Spec0004 R1–R5 and success criteria pass with RED/GREEN evidence.
- [ ] Save initialization, streaming append and final overwrite failures cannot produce item success.
- [ ] Complete generated output survives a final save failure in memory and is recoverable without another model/LLM pass where retry-save applies.
- [ ] Mixed-queue status, cancellation, collision and successful-save behavior remain correct.
- [ ] Task0003 remains separately open with its broader criteria untouched.

## Plan

- [ ] Persist worker ground0020, inspect actual save/result seams, preregister deterministic failure fixtures and reproduce before changes.
- [ ] Propagate throwing I/O and item failure; retain complete result with clear completeness state and reuse existing retry/output controls for save recovery.
- [ ] Test assembled queue/file failure and recovery, then run applicable full gate and independent review.

## Ownership and integration contract

Worker B owns `UI/TranscriptionJob+Processing.swift`, `UI/TranscriptionJob+Queue.swift`, save/streaming/result extensions, batch item/result model, recovery-related `UI/TranscribeView+Queue.swift`, new isolated file-writer/result helper and batch save tests. Worker A owns `UI/TranscriptionJob.swift` and `+Factories.swift`; Worker B puts additional save state in an owned helper rather than concurrently changing those files, or sends a tiny requested patch to A. No edits to context config, recording or insertion-review controller/view. Worker B alone edits queue start; Worker A sends the exact context snapshot helper signature and B inserts one call before async work. Batch factory selection must not be recaptured per queue item. Coordinate localized keys with root.

## Notes

- 2026-11-10 — Risk register: write failure swallowed (Conditional, reproduce blocked output/file handle failure); partial progress confused with complete result (Conditional, explicit result completeness and failure fixture); recovery reruns expensive generation (Conditional, count fake model/LLM calls); existing successful file clobbered (Conditional, collision fixtures); concurrent context integration (Conditional, exclusive queue ownership and helper contract). No planned new format/queue/parallelism. Validation cannot establish universal disk durability or future free-space availability.

- Implementation review: initial frozen batch patch b384c0ce5c17add545a87e31a37e0a229b8395a9e02c674c6e6fb888d1ef8b71/tree31f4932b5ada6b3363e1ac5030b0ca10ec6df171 received critical Spec finding `batch-case-alias-overwrite`: save-only retry could overwrite a completed destination through a case/symlink alias. Disposition resolved by Foundation file-resource identity/isEqual, metadata cache invalidation and symlink-aware reservations, conservative fallback without lowercase assumptions. Independent reviewer `/root/review_batch_115` delta16a32c459543011b6c52963dfb796664019c6fda020d052ae292dad34c22d0fa/treed1db2313d7de6985529b1e76955a51513cfcf726 reports Standards0/Spec0, ship as-is. Actual public-flow regression35tests passed with both filesystem collision cases executed, original bytes preserved, distinct retry destination and no ASR replay. Main integrated runtime/full gate/UI remain pending; not Done.
- Worker TDD closeout exercised five stateful operators: four killed directly; a readiness-predicate survivor exposed a missing fresh-queue/no-Whisper-model fixture. The added differentiating case killed it while production predicate remained unchanged. Mutation receipt retained under `.agentic/reviews/batch-mutation-closeout.json`; this is focused test evidence, not integrated app runtime.

## Definition of Done

- [ ] Source and output evidence traceable to SHA; save failures truthfully surfaced and recoverable result verified.
- [ ] Applicable full gate and fresh-context review closed.
- [ ] Parent task0003's remaining scope reported, not marked done; release owner receives bounded claims/limits.
