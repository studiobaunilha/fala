# GROUND-0017: Explicit manual personalization boundaries

**Status:** recorded
**Decision:** Reuse local Parakeet vocabulary collections and require explicit approval before persisting analyzer-derived corrections
**Decision ref:** doc/specs/0002-manual-vocabulary-contexts.md; doc/specs/0003-approve-learned-corrections.md
**Confidence:** Conditional
**Stakes:** medium × reversible

## Decision and confidence

Keep personalization explicit: opt-in named recognition contexts with recording/run snapshots, plus a separate approval action for global reusable corrections. Reuse the store/runtime, Codable settings, analyzer and existing upsert callback. No new context collection or model service. The source paths and comparable interfaces are established; confidence is Conditional on the preregistered migration/isolation/lifecycle tests and assembled checks in PRISM0018. This receipt records the implementation evidence for the bounded personalization changes. Scope was authorized by the owner's request to deliver and release the bounded improvements; the specs record the selected defaults, not a request for another product interview.

## Evidence

### E1 — Existing recognition vocabulary is reusable, but lifecycle capture must change

**Tier:** Primary
**Strength:** Medium
**Provenance:** A1, A2, B1, C1, D1

The pinned FluidAudio source below establishes Parakeet terms/aliases and acoustic rescoring; Package.resolved records the SDK pin. Current recording setup reads configuration at start but rereads it for transcription, while the public Parakeet constructor's provider loads live AppConfig. GUI file factories capture configuration at job/window construction. Named profiles therefore need an immutable recording-start/run-start store to avoid retargeting. TypeWhisper's explicit manual workflow identity is a behavioral reference; no GPL code will be copied. Default remains the old global store; named contexts exclude global ASR hints, while final global replacement rules still apply. This is vocabulary separation, not complete text isolation.

### E2 — Approval can gate the existing persistence callback without changing extraction

**Tier:** Primary
**Strength:** Medium
**Provenance:** A3, B1, C2, D2

VoiceInk documents approval/dismissal for local learning. Fala already produces a bounded analyzer candidate after review editing and directly invokes a persistence callback; moving that call behind an explicit global-rule proposal uses the existing seam. Applying text and authorizing a future rule are separate outcomes. A per-review identity and consume-before-callback are necessary because editing awaits activation while a newer review may arrive. No new external-field observation or AI classification is warranted.

### E3 — Native visible controls and explicit privacy boundaries are the simplest path

**Tier:** Primary
**Strength:** design choice
**Provenance:** A1, A4, C1, C2

Use native labelled selection and term editing, an opt-in Contexts switch and a Default fallback. Do not include profile data in text-provider prompts or change manual rule APIs. Learning proposals are local/in-memory, label their global effect and discard on dismissal. These defaults bound the requested improvement and the existing state, not a claim of measured user preference. An unsupported Whisper explanation is preferable to silently changing engines or introducing another conditioning path.

### E4 — Bound async ownership fixtures without external selection capture

**Tier:** Primary
**Strength:** Medium
**Provenance:** A5, B1, C3, D3

The operator sweep found an actual missing distinguishing scenario: recording A can suspend in selection capture, be stopped, then resume after recording B starts. The new identity conjunction is required in that reachable state; treating its OR mutant as equivalent would be wrong. The concrete SelectionCapture cannot be paused without sending Cmd-C and reading the user's clipboard. Reuse the existing constructor-injection shape: an internal optional asynchronous selection callback defaults to the same concrete capture implementation, leaving public construction unchanged. A test gate supplies only synthetic nil selection; XCTest expectation deadlines, guards and unconditional release keep regression failures bounded. This is a verification seam, not a product capability or new context collection. DI and its regression/timeout tests reopen only this delta for independent review.

### E5 — Retired capture cannot publish into a new recording

**Tier:** Measurement
**Strength:** High
**Provenance:** C4

The synthetic A-start/suspend → A-stop → B-start/suspend → A-resume sequence with non-nil selections reproduced a real productive-source failure, not only a mutant: one test/one assertion observed stale A selection in the shared pending selection of B. The minimum fix awaits into a local value and validates operation identity plus cancellation before publishing the selection. The same regression and neighboring ownership/lifecycle/lease cases then passed20tests/0failures. This establishes the controlled state transition, not real clipboard behavior or general app focus correctness. The existing selection path remains the default; injected callbacks avoid all external selection collection.

## Source register

- **A1:** [VoiceInk Vocabulary](https://tryvoiceink.com/docs/vocabulary), names/terms versus replacements; reopened as the behavioral reference. (accessed 2026-11-10 via web)
- **A2:** [FluidAudio VocabularyBoostingSession pinned c8b41f9](https://github.com/FluidInference/FluidAudio/blob/c8b41f98eae668794dd0083bbe028fe7e6585051/Sources/FluidAudio/ASR/Parakeet/SlidingWindow/CustomVocabulary/VocabularyBoostingSession.swift), model-independent acoustic rescoring; pinned source consulted directly. (accessed 2026-11-10 via HTTPS/local dependency)
- **A3:** [VoiceInk Auto Learn](https://tryvoiceink.com/docs/auto-learn-dictionary), Choose How to Review / Correct and Save: local user approval and dismissal; reopened. No timer/count copied. (accessed 2026-11-10 via web)
- **A4:** [Apple HIG Pickers](https://developer.apple.com/design/human-interface-guidelines/pickers.md), Best practices: predictable ordering and in-context choice; reopened Markdown. Adapted as native selection, not iOS wheel UI. (accessed 2026-11-10 via web)
- **B1:** [TypeWhisper WorkflowService pinned 2a0ae3e](https://github.com/TypeWhisper/typewhisper-mac/blob/2a0ae3e2ec4a627dbc6e90b1a2c9c72757c8d860/TypeWhisper/Services/WorkflowService.swift), fetched raw `forcedWorkflowMatch` / `matchWorkflow`; exact short excerpt `kind: .manualOverride`. Applies to manual identity only; approval uses Fala's existing candidate/callback seam, not TypeWhisper code. (accessed 2026-11-10 via HTTPS)
- **C1:** `Sources/FalaCore/Modes/DictationMode.swift:124,228`; `Core/ParakeetTranscriber.swift:32`; `Core/ParakeetVocabularyStore.swift:49`; `UI/TranscriptionJob.swift:63`; `UI/TranscriptionJob+Factories.swift:52`; `Modes/BatchMode.swift:25`: live versus stale configuration seams. `Config/ModeConfig.swift:3` has prompts but no vocabulary profiles. (accessed 2026-11-10 via local read-only source)
- **C2:** `Sources/FalaCore/UI/InsertionReviewController.swift:145`; `UI/InsertionReviewView.swift:133`; `Core/CorrectionLearningAnalyzer.swift:9`; `App/AppDelegate.swift:102`; `UI/AppSettings+ReplacementRules.swift:5`; `Tests/FalaTests/ReplacementRuleTests.swift:5`: existing edit/candidate/persistence separation and whole-word regression. (accessed 2026-11-10 via local read-only source)
- **D1:** `git log HEAD --oneline -- Sources/FalaCore/Core/ParakeetRuntimeManager.swift Sources/FalaCore/Core/ParakeetVocabularyStore.swift Sources/FalaCore/Config/ModeConfig.swift`: `cc4a29f` Ultra/shared path, `e7ce8a5` serialization, `bc7af86` earlier runtime/store. Active worktrees inventoried at base3ba31a7; no named profile in inspected baseline. (accessed 2026-11-10 via Git)
- **D2:** `git log --all --oneline --grep='vocab\|context\|correction' -i`: `145f3aa` learns manual edits, `e385ffe` bounds final rules; task0005 and current controller preserve target capture before dismissal. (accessed 2026-11-10 via Git/local task)

- **A5:** [Swift concurrency language guide source](https://raw.githubusercontent.com/swiftlang/swift-book/main/TSPL.docc/LanguageGuide/Concurrency.md), Defining and Calling Asynchronous Functions: explicit suspension permits other operations to run before resumption. Used only to ground interleaving, not timing or feature quality. (accessed 2026-11-10 via HTTPS)
- **C3:** `Sources/FalaCore/Modes/DictationMode.swift:12,57`; `UI/InsertionReviewController.swift:38`; `Tests/FalaTests/InsertionReviewControllerTests.swift:69`; `Tests/FalaTests/DownloadNotificationDispatcherTests.swift:39`: existing constructor-injected async behavior and XCTest bounded expectation pattern. New seam only affects test injection; default selection path is unchanged. (accessed 2026-11-10 via local source)
- **D3:** `git log -4 --oneline -- Sources/FalaCore/Modes/DictationMode.swift Sources/FalaCore/UI/InsertionReviewController.swift`: `82f9850` preserves review target across async work using injected controller dependencies; `232442f` has earlier dictation reliability patterns. (accessed 2026-11-10 via Git)

- **C4:** Isolated context checkout `.agentic/reviews/context-mutations/selection-ownership-real-red.log` (1test/1failure), `selection-ownership-restored-green.log` (20tests/0failures); `Tests/FalaTests/VocabularyRecordingOwnershipTests.swift`; reproduction `bash scripts/swift-env.sh test --filter VocabularyRecordingOwnershipTests`. Frozen corrected source/test export `.build/verification/context-di-review-source-v2/manifest.json` identifies actual bytes. (accessed 2026-11-10 via local test execution/logs)

## Limitations and reversal

No accuracy superiority, UI usability study, real microphone capture or guaranteed insertion is established. Static seams support bounded implementation, conditional on planned checks. Failure to preserve Default, global-rule disclosure, snapshots or no-preapproval persistence stops exposure until fixed. Batch save has its own worker-ground0020 and is not grounded by this personalization receipt. No new implementation run preceded this plan.

## Audit path

Run `node /Users/ale/.agents/skills/ad-ground/scripts/validate-record.mjs doc/research/0017-ground-manual-personalization.md`. Reopen only changed claims/sources during review; structural validity does not prove source content. No duplicate independent survey was performed.
