# PRISM-0018: Accept bounded personalization and truthful saves

**Status:** draft
**Decision ref:** doc/tasks/0006-manual-vocabulary-contexts.md; doc/tasks/0007-approve-learned-corrections.md; doc/tasks/0008-truthful-batch-save-failures.md

## Decision

Allow the three specified slices into the new release only after each meets its deterministic contract, assembled-path checks and independent review. This is technical operation and bounded fit-for-use validation, not a recognition-quality superiority study. The owner authorized the release; release/signing/distribution gates remain the release owner's responsibility.

## Objective

Make manual recognition context selection predictable, prevent silent rule learning, and avoid declaring unsaved output complete. Setting: local deterministic tests plus the built macOS app and public/authorized file fixture. Rigor is proportional to reversible feature state and the potentially harmful persistence/save mistakes. No domain adapter or private vocabulary corpus is required.

## Evaluation question

Does every preregistered scenario below produce the specified profile, persistence and output result, without regression of the existing target/boundary/cancellation contracts?

## Claim

Passing results support correct routing/lifecycle and truthful outcomes for the inspected scenarios and assembled artifact. They do not support improved name accuracy, universal insertion reliability, broad codec support, market benefit or disk durability guarantees.

## Evidence

Retain RED/GREEN focused test logs, exact source state, independent review dispositions, make check output, candidate build identity and assembled scenario receipts. Treat mocked callback outcomes as controller evidence; built-app checks establish real presentation/path integration. Keep these evidence roles distinct (M1).

## Tasks

Independent unit is one versioned scenario. Repeated callbacks in one scenario remain one scenario, not extra samples. Cases are exhaustive contract examples, not a statistical population sample. No sample-size or power claim is made. Freeze expected input/output fixtures before each deciding test run; record omissions, failures and modified expectations explicitly.

| Key | Fixture/action | Required observation | Owner |
|---|---|---|---|
| C1 | Legacy configuration; missing context fields | Disabled/default, identical global effective store and unchanged saved rules | task0006 |
| C2 | Two profiles with distinct aliases; empty/duplicate CRUD; missing selected ID | Named vocabulary excludes other/global ASR hints; empty stays empty; missing resolves Default; validation deterministic | task0006 |
| C3 | Start recording with A, mutate/rename/delete A and select B before stop; quick-tap/start-failure/cancel exits | In-flight identity/revision/name/store stay A; next operation uses B/Default; no old result retarget; every early exit clears the captured snapshot | task0006 |
| C4 | Start a two-item queue with A, change selection between items, next run B | Capture A before first suspension; one A snapshot for first run; next run B; no job-window stale config; CLI once-loaded config equivalent | task0006 |
| C5 | Change context with injected text processor and existing global rules | Prompts/provider unchanged; existing whole-term/non-cascade rules still apply globally | task0006 |
| C6 | Built contexts editor/selector with Parakeet then Whisper | Labelled native controls, visible selection and explicit Whisper limitation; no silent engine switch | task0006 |
| L1 | Real controller edit Nico→Niko; spy callback | Edit happens first; pending global-rule pair; no save until Approve; repeated Approve saves once | task0007 |
| L2 | Reject/dismiss/timeout/new review plus late old approve/edit/Undo/dismiss/hover callbacks and suspended activation | No save; no reversal of applied edit; all old callbacks identity-guarded; revalidate after await so new review is not replaced or acted on by stale completion | task0007 |
| L3 | Undo/missing or failed activation/no-change/punctuation/unrelated change | Existing fail-closed and analyzer contracts remain; no learned proposal/save | task0007 |
| L4 | Built edit and proposal panel, manual rule controls | Apply/edit and global-rule approval visibly distinct; manual add/remove still works | task0007 |
| S1 | Deterministic blocked output/open/append/final-write failure | Error propagates; no completed path/success; partial content never labelled complete | task0008 |
| S2 | Mixed queue with a successful item and failed-save item; retained full text | Accurate per-item/summary outcomes, preserved successful file, complete text recoverable in memory | task0008 |
| S3 | Choose writable destination and retry retained complete result | Expected contents saved; fake ASR/LLM call counts unchanged during save-only retry; no missing-model readiness block | task0008 |
| S4 | Cancel, same-basename files and normal save; built public-file success/failure/recovery | Existing cancellation/collision contract preserved; real saved bytes match expected result; truthful failed artifact status | task0008 |

## Measures

Primary measures are equality of effective store/snapshot identity, callback invocation counts, exact final text/file bytes and item states. Guardrails are no cloud-prompt enrichment, no preapproval persistence, no substring replacement, no false completion and no expensive rerun for save-only retry. Group evidence by slice/engine and scenario; do not average a safety failure away. Native UI checks assess readable labels and operable actions, not a quantified usability score. No timing threshold is invented (M2).

## Data sources

Baseline3ba31a7; current Codable/analyzer/controller/queue behavior and tests; ground0017; worker-ground0020; public cached JFK audio if available or another public/authorized file identified before execution. Synthetic names and paths contain no personal data. Live microphone permission, cross-app focus and untested codecs remain access/coverage gaps unless release owner explicitly exercises them. Retain output receipts with SHA and candidate path; avoid vocabulary snippets in general logs.

## Decision rule

Design choice fixed before deciding runs: proceed per slice only when every applicable scenario above passes, the canonical local gate passes and fresh-context findings are resolved. A failed guardrail means revise and rerun its changed coverage before exposure. Missing assembled evidence means hold that slice; do not infer it from mocks. If a defect cannot be safely fixed within the bounded spec, escalate a release scope cut with its cause; do not widen into OCR, cloud enrichment or another queue. Optional environment/model-dependent checks may be recorded as unavailable, but the release owner must then exclude their claims or retire the gap before exposing the affected slice. No measured accuracy claim is permitted from these results.

## Limits

Deterministic operation checks are suitable for routing, persistence and I/O contracts (M1/M2), but do not estimate user benefit or name-recognition effects. One public file establishes assembled pipeline operation only. Asynchronous focus is still best effort; write success does not prove durable storage after machine failure. A future quality comparison needs authorized speech and preregistered error/false-correction measures and is not a hidden requirement for this bounded delivery.

## Sources

### M1 — Goal-linked contract evidence
- Source: `doc/specs/0002-manual-vocabulary-contexts.md`, `doc/specs/0003-approve-learned-corrections.md`, `doc/specs/0004-truthful-batch-save-failures.md` (accessed 2026-11-10 via local source)
- Supports: Versioned scenario inputs/expected outputs traceable to each promised behavior.
- Contribution: Gives the exact state/callback/file outcomes the worker must observe.
- Adaptation: Deterministic scenarios use existing injected services; assembled UI/files check the integration those fakes cannot establish.
- Retained limit: Requirements are normative choices, not independent evidence that users benefit or names improve.

### M2 — Design selection follows the objective
- Source: https://www.itl.nist.gov/div898/handbook/pri/section3/pri33.htm (accessed 2026-11-10 via web)
- Supports: Match method to the decision and available resources rather than invent a broad benchmark.
- Contribution: Separates operation/contract checks from a comparative quality experiment.
- Adaptation: Use binary contract checks plus bounded assembled scenarios for these three reversible slices; all applicable checks must pass by design choice.
- Retained limit: NIST supplies no Fala sample size, acceptance threshold or proof of quality; none is borrowed.
