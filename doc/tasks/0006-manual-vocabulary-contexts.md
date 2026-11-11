# Task 0006: Deliver manual vocabulary contexts

**Status:** planned
**Created:** 2026-11-10
**Owner:** contexts delivery role
**Execution:** AFK
**Spec ref:** doc/specs/0002-manual-vocabulary-contexts.md
**Evidence ref:** doc/research/0017-ground-manual-personalization.md
**Evaluation ref:** doc/research/0018-prism-personalization-save.md

## Context

Expose existing Parakeet recognition hints as manually selected collections with explicit lifecycle snapshots. Source baseline `3ba31a7`; the owner authorized implementation and a new release, including routine decisions in the bounded spec. Do not stop at planning. This task's first worker receives the whole context slice, not a horizontal model-only fragment.

## Acceptance Criteria

- [ ] Spec0002 R1–R7 and its success criteria pass with receipts.
- [ ] Legacy Default/disabled behavior is unchanged; named-context isolation is demonstrated.
- [ ] Recording and queue-run snapshots survive mid-operation changes and all cleanup exits.
- [ ] Native selection/editor surfaces are usable and Whisper limitation is visible.
- [ ] Prompts/provider values, global final corrections and correction-approval callbacks remain unchanged.

## Plan

- [ ] Add tracer tests for configuration migration, isolated effective store and immutable operation snapshot; observe RED before production changes.
- [ ] Add compact Codable context model/config and settings methods, then native settings editor and operation selectors.
- [ ] Wire immutable stores through dictation resolver and queue run without duplicating model assets; use one shared active-run configuration instead of fresh AppConfig reads during operations.
- [ ] Verify focused/full gates, assembled UI and cached public audio; obtain fresh-context review of this slice once.

## Ownership and integration contract

Worker A owns new context model/settings/view files; `Config/AppConfig.swift`, `Core/ParakeetVocabularyStore.swift`, `Core/ParakeetTranscriber.swift` if needed, `UI/AppSettings.swift`, `UI/AppSettings+ParakeetVocabulary.swift`, `UI/SettingsView.swift`, `UI/SettingsView+Persistence.swift`, settings-navigation definition, `UI/StatusBarController*`, context display in feedback, `Modes/DictationMode.swift`, `App/AppDelegate.swift`, `UI/TranscriptionJob.swift`, `UI/TranscriptionJob+Factories.swift`, `Modes/BatchMode.swift`, context-specific tests and localization keys. It does not own review controller/view or save processing/queue code. Context-only modifications to shared test files are coordinated with root.

Public value contract: effective vocabulary is a `ParakeetVocabularyStore` resolved from a captured `AppConfig`, not a live read closure. Add explicit profile identity/name plus terms with immutable value semantics; keep existing global `parakeetVocabularyStore` semantics for Default. The dictation resolver must receive the recording-start configuration and create/use a transcriber whose provider returns that fixed store; reusing the existing runtime is preferred to new per-profile model caches. GUI batch transcriber pool currently captures configuration at job/window creation: retire this stale-selection risk at run start. Worker A should expose an internal run-config capture/reset helper to the batch worker; only Worker B edits `TranscriptionJob+Queue.swift` to invoke it at run start if that file must change. Exchange exact signature before either edits the boundary. CLI already captures configuration once.

Worker A does not change `InsertionReviewController`'s constructor/learn callback. `AppDelegate` remains the existing persistence callback owner and receives only approved pairs from Worker C.

Batch coordination exception: Worker B may edit only `TranscriptionJob.swift`'s `transcribe()` function in its isolated worktree to bypass readiness/warming for save-only retry. Root integrates that hunk separately; Worker A owns the rest of that file. Worker B owns `Queue.preparationConfig()`; Worker A sends its context-snapshot delta for B to apply. No concurrent uncoordinated edits to shared localization resources: use separate new-key fragments for root/A integration.

## Notes

- 2026-11-10 — Pre-build risk register: wrong profile leaks names (Conditional; pure store-isolation and immutable snapshots before wiring); file pool stale at window creation (Conditional; run-start reconstruction/helper tested); global replacement hints merged unintentionally (Strong after explicit spec distinction, test required); unsupported Whisper promises (Strong; no rollout, visible limitation); CTC loading/fallback and serialization (Conditional; preserve existing path and public-audio assembled check); private context/cloud prompt leakage (Conditional; no new prompt use and injected-processor assertion). Stop condition: no Insufficient critical design unknown remains; these Conditional items are routed to named checks before exposure.

- 2026-11-10 — Implementation candidate is frozen at source patch SHA256 `4b425fa418d36af43dd5fa3e571b9c7dcd14d56018424abc6ed3165d1504d9f8` in isolated `/Users/ale/.codex/worktrees/fala-contexts/fala/.agentic/reviews/contexts-candidate.patch`, baseline3ba31a7. Recording tracer ran before production: final RED1test/1causal failure/0unexpected (resolver read a changed vocabulary); final text continued using the current global correction, guarding against an unintended whole-configuration freeze. Initial setup compile error and a too-short speech fixture were corrected before the deciding RED; the earlier output and final RED log remain separate.
- First GREEN22tests/0failures; final focused32tests/0failures/0unexpected includes immutable concurrent vocabulary leases over one runtime, queued cancellation, start-failure/cancel/stop cleanup, deleted-profile queue snapshot, pool regressions and localization key coverage. Full-tree strict lint exited0;32new catalog keys have en/es/fr translations plus sourcept-BR, with no missing entries in the explicit current-minus-base enumeration. No user vocabulary, contacts, clipboard or screen content collected. Tests use an injected vocabulary persistence callback; context CRUD does not trigger model/LLM warmup.
- Evidence paths in that isolated checkout: `.agentic/reviews/context-recording-red.log`, `context-recording-red-final.log`, `context-first-green-aborted.log` (stopped own swift-test after scheduling ambiguity, exit130), `context-first-green.log`, `context-final-focused.log`, `context-lint.log`, `context-localization-coverage.json`. The candidate patch includes tiny queue/transcribe snapshot hooks to merge as hunks after the batch patch, not whole-file replacement. No commit/push/release by this worker.
- Pending: fresh-context review dispositions, combined make check, built native UI and real cached Ultra/CTC runtime smoke owned by the release integrator. Do not infer runtime accuracy or app usability from these tests. Snapshot cleanup is before the quick-tap branch; quick-tap's real floating UI was not exercised by this worker. Protocol and read-only cache inventory are in the isolated `.agentic/reviews/contexts-runtime-handoff.md`.

- 2026-11-10 — Operator closeout: three new recording-state operators are killed by causal tests (O1 identity inversion, O2 catch-ownership inversion, O3 conjunction→disjunction). The initial interrupted O1 broad run is explicitly invalid/not scored; its clean targeted rerun is retained. O3 required a small internal async selection injection seam and bounded synthetic A/B capture regression, without changing public construction or collecting clipboard data. Independent delta review found an actual stale selection publication before the guard; productive source RED1test/1failure reproduced it, then a local-result/publish-after-ownership fix passed. Mode sourceSHA256 `9b084de87ce914dff199100d67fedf7780e85279527c9bcba66f3efbf88487d8` is restored and frozen; root reports DI/selection-fix delta review closed.
- N1 exploratory survivor was also closed: Default recognition hints retain their captured spelling while final global text rules remain current. Original new test GREEN1/0; N1 mutant RED7tests/2assertions; no production change for this gap. Remaining ten unvisited semantic probes are NOT EXECUTED/deferred, neither killed nor equivalent; they remove whole calls/assignments or alter value projections rather than the three mandatory state transition operators. PRISM0018/spec0002 do not enumerate14mutants as a release gate; the release owner chose required assembled UI/offline ASR/CTC over additional unvisited exploration. No known survivor is waived.
- Final restored focused47tests/0failures/0unexpected and full-tree strict lint exit0. Closeout receipts in isolated `.agentic/reviews/context-mutations/closeout-manifest.json`; N1-test-only patchSHA256 `c5b1e5e78315f9952f571cd8869fdd46dbd109d4a7abdb34d35407451732d951` applies on top of reviewed6020delta. Combined final deltaSHA256 `2b06d4ebeb0e8e1ad2134457fd4fbabaae7be3d3607e81ccce70cea8b56e2423` instead applies directly on4b425fbase. These are alternate application paths, not cumulative patches. Combined make check, assembled native UI and actual cached Ultra/CTC remain pending release-owner checks; task is not marked L4 done by this worker.

## Definition of Done

- [ ] Acceptance criteria, make check and assembled-path checks complete at identified SHA.
- [ ] Fresh-context Standards/Spec review dispositions closed; new nonblocking limits stated honestly.
- [ ] Release owner receives source delta, behavior/flag note, tests and public-safe claims; no autonomous publish by this worker.
