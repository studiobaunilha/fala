# GROUND-0008: Evaluate batch recovery and speaker-labelled files incrementally

**Status:** recorded
**Decision:** Preserve the existing batch pipeline, assess local work in progress before new speaker infrastructure, and evaluate an offline speaker-labelled file path before a production proposal.
**Decision ref:** doc/tasks/0003-batch-recovery-and-export.md; doc/tasks/0004-evaluate-speaker-labelled-files.md
**Confidence:** Strong
**Stakes:** medium × reversible

## Decision and confidence

The most grounded path is a small evaluation around the existing queue and adapters, starting with FluidAudio's offline diarization support and an explicit timestamp-to-word alignment stage. This shares the application's current dependency and follows the upstream prerecorded-file example (A1/B1), preserves its queue, cancellation, and instrumentation (C1–C4), and respects the recorded removal of the former speaker-label UI (D1). SpeakerKit is a valid alternative for comparison (A2/B2), not a reason to upgrade a second SDK at the same time. Confidence is Strong for this evaluation sequence, not for the quality or fitness of a particular diarization model. Production adoption remains undecided.

The selected-model and literal-correction contracts are tracked separately in tasks 0001 and 0002. Their implementation belongs to their respective delivery agents. Tasks 0003 and 0004 are queued proposals, not a claim that their checks have run.

## Evidence

### E1 — Batch support already has end-to-end machinery

**Tier:** Primary
**Strength:** Medium
**Provenance:** C1, C2, C3, C4, D2

The inspected base `8df48a1` has a multi-file GUI queue, duplicate-input filtering, retryable and terminal item states, cancel propagation, reuse/prewarming of engine instances, file output, and timing by execution stage. The CLI also transcribes individual files. These are code observations, not a successful run of those paths in this study.

The next useful batch slice is an assembled-path check of cancellation, retry, conflicting output names, and file read/write failure. It should reproduce a failure before changing behavior. There is no grounded need for another queue, parallel jobs, a scheduler, or persistent resume in this slice. This prioritization is a design choice; the potential failure cases are not reported as proven defects.

### E2 — Published speaker labelling and local work are different states

**Tier:** Primary
**Strength:** Medium
**Provenance:** C5, D1

`SettingsCleanupSourceTests` checks that settings, batch sources, and official docs no longer advertise or reference the removed diarization feature. Commit `c8a32d1` removes that surface and adds the cleanup assertions. A new implementation must deliberately replace the relevant contract and tests; it must not quietly bypass the existing checks.

A separate working-copy status inspection found uncommitted work around timed transcripts, speaker diarization, timeline alignment, and associated tests. Only filenames and status were examined for this inventory. Its implementation quality, completeness, and compatibility have not been assessed. It must be reconciled before choosing which components to implement anew. No source content was copied from that work, and nothing in the original working copy was edited.

### E3 — Offline and live diarization are separate choices

**Tier:** Primary
**Strength:** Medium
**Provenance:** A1, A3, A4, B1

FluidAudio documents an offline pipeline with segmentation, embeddings, clustering, and timeline reconstruction, plus file-backed input for long recordings. Its live diarizers have different constraints: Sortformer documents four fixed speaker slots; Nemotron 3 documents up to eight speakers with streaming and offline profiles. These interfaces are real documented candidates, not verified quality results on Portuguese or proof that any one is optimal for Fala.

The current need is prerecorded files. Starting offline avoids imposing a live-latency constraint that the feature does not require. The exact model, asset availability, OS compatibility, and memory behavior must be measured before rollout. The existence of a Swift API does not establish those outcomes.

### E4 — SpeakerKit offers transcript alignment, with a separate integration cost

**Tier:** Primary
**Strength:** Medium
**Provenance:** A2, A5, B2

The Argmax Open-Source SDK documents SpeakerKit as an on-device Core ML pipeline. Its example attaches diarization to WhisperKit results with `addSpeakerInfo(to:)`, and offers segment/subsegment strategies and RTTM output. That is a useful alignment reference, not a direct adapter for the current string-only Parakeet interface.

The SDK is MIT; it also incorporates components and model assets with their own terms. This code licence must not be treated as the licence for every model. Open-source and Pro SDK capabilities are explicitly distinguished upstream. No paid SDK feature is assumed available to the free application.

### E5 — A usable speaker transcript is more than a timeline

**Tier:** Primary
**Strength:** Medium
**Provenance:** A2, A6, B2, C4

SpeakerKit's merge example and MacWhisper's published feature set both separate speaker identification from transcribed text and export. MacWhisper advertises speaker labels, a transcript editor, and export; its marketing does not prove accuracy. Fala's current `AudioTranscribing` interface returns strings and progress windows, without a speaker-attributed timed result. A future file feature therefore needs an explicit alignment contract, preserving unresolved assignments rather than fabricating certainty. This architecture recommendation is a design choice supported by the interface gap.

The evaluation must report diarization error separately from speaker-attributed word errors. A correct time-only timeline can still assign transcript words incorrectly. No numeric approval threshold is selected here.

## Source register

All sources were accessed on 2026-11-10. Upstream `main` URLs describe the observed current API and remain mutable; an implementation must pin the actual SDK and model identities.

- **A1:** [FluidAudio API reference](https://raw.githubusercontent.com/FluidInference/FluidAudio/main/Documentation/API.md), lines 23–81: offline file-backed processing and distinct streaming lifecycle. Accessed via web/HTTPS. (accessed 2026-11-10 via web/HTTPS)
- **A2:** [Argmax SDK README](https://raw.githubusercontent.com/argmaxinc/argmax-oss-swift/main/README.md), lines 512–614: SpeakerKit, transcript merge strategies, and RTTM. Accessed via web/HTTPS. (accessed 2026-11-10 via web/HTTPS)
- **A3:** [FluidAudio Sortformer documentation](https://raw.githubusercontent.com/FluidInference/FluidAudio/main/Documentation/Diarization/Sortformer.md), lines 1–21: four-speaker limit and limitations. Accessed via web/HTTPS. (accessed 2026-11-10 via web/HTTPS)
- **A4:** [FluidAudio Nemotron 3 documentation](https://raw.githubusercontent.com/FluidInference/FluidAudio/main/Documentation/Diarization/Nemotron3.md), lines 1–45, and [NVIDIA model card](https://huggingface.co/nvidia/Nemotron-3-Diarization/blob/main/README.md): eight-speaker profiles; model card declares OpenMDW-1.1. Asset access and distribution terms remain a pre-integration check. Accessed via web/HTTPS. (accessed 2026-11-10 via web/HTTPS)
- **A5:** [Argmax SDK licence](https://raw.githubusercontent.com/argmaxinc/argmax-oss-swift/main/LICENSE), MIT; README lines 19–31 distinguish the Pro SDK and lines 621–625 preserve third-party terms. Accessed via web/HTTPS. (accessed 2026-11-10 via web/HTTPS)
- **A6:** [MacWhisper](https://www.macwhisper.com/), advertised speaker identification, editor, and export. Accessed via web; product claims only. (accessed 2026-11-10 via web/HTTPS)
- **B1:** `FluidInference/FluidAudio:README.md:498–530`, [file-processing example](https://github.com/FluidInference/FluidAudio#offline-speaker-diarization-pipeline). Fetched block: `let result = try await manager.process(url)`. This is the reference for prerecorded input rather than a live microphone pipeline. Accessed via web/HTTPS. (accessed 2026-11-10 via web/HTTPS)
- **B2:** `argmaxinc/argmax-oss-swift:README.md:556–581`, [combining transcription](https://github.com/argmaxinc/argmax-oss-swift#combining-with-transcription). Fetched block: `let speakerSegments = diarization.addSpeakerInfo(to: transcription)`. Accessed via web/HTTPS. (accessed 2026-11-10 via web/HTTPS)
- **C1:** `Sources/FalaCore/UI/TranscriptionJob.swift:76–105`, multi-file selection and duplicate-input filtering; `:131–163`, retryable-item execution. Accessed by local read. (accessed 2026-11-10 via local read)
- **C2:** `Sources/FalaCore/UI/TranscriptionJob+Queue.swift:75–94`, warmup and cancellation; `:135–142`, preparation config. Accessed by local read. (accessed 2026-11-10 via local read)
- **C3:** `Sources/FalaCore/Core/BatchTranscriberPool.swift:130–197`, engine reuse, warmup, and Whisper model configuration; `Sources/FalaCore/Core/BatchAudioPreparer.swift:27–58`, sample preparation. Accessed by local read. (accessed 2026-11-10 via local read)
- **C4:** `Sources/FalaCore/Protocols/AudioTranscribing.swift:1–40`, string/progress interface; `Sources/FalaCore/UI/TranscriptionJob+Execution.swift:5–109`, file pipeline and instrumentation. Accessed by local read. (accessed 2026-11-10 via local read)
- **C5:** `Tests/FalaTests/SettingsCleanupSourceTests.swift:4–38` and `:78–105`, removal assertions; local-only working-copy status inventory retained separately by the orchestrator. Accessed by local read and `git status --short`; filenames only for uncommitted work. (accessed 2026-11-10 via local read)
- **D1:** `git log main --oneline --all --grep=diar` and `git show --stat c8a32d1`: `c8a32d1` removes diarization settings/docs; earlier `7288f98` added diarization formatting instructions to LLM post-processing. Accessed by local Git. (accessed 2026-11-10 via local Git)
- **D2:** `git log main --oneline -- Sources/FalaCore/UI/TranscriptionJob+Queue.swift Sources/FalaCore/Core/BatchTranscriberPool.swift`: `05dd325` adds file queue/preparation, `635543a` improves stage instrumentation/cancellation, `84ee781` adds queue timing UI. Active branches were surveyed with `git worktree list` and `git branch -a`; isolated delivery worktrees are not evidence of shipped behavior. Accessed by local Git. (accessed 2026-11-10 via local Git)

## Limitations and reversal

No ASR/diarization model was downloaded or executed, no benchmark was run, and no production file was changed. This record establishes a grounded sequence for evaluation, not measured speed, memory, licence compatibility for an entire artifact set, or speaker accuracy. Existing local work may change the best integration boundary after it is inspected and tested.

The recommendation would change if the existing work already provides a validated assembled path, if the selected FluidAudio version cannot support the intended offline model/OS, or if asset access or model terms make that path unsuitable. In that case compare SpeakerKit or another documented candidate without weakening the application's privacy or free-distribution requirements.

## Audit path

Run `node /Users/ale/.agents/skills/ad-ground/scripts/validate-record.mjs doc/research/0008-ground-batch-and-speaker-labels.md`, then reopen the external source sections and local locators. Structural validity proves the claim-to-source map, not the model quality. Review task 0004 before choosing production quality thresholds or enabling speaker labelling.
