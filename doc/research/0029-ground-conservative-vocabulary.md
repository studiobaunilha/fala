# GROUND-0029: Preserve transcript spelling outside declared vocabulary forms

**Status:** recorded
**Decision:** Require native per-term similarity 1.0 for every vocabulary term; retain the SDK's case, punctuation and word-segmentation normalization and acoustic comparison.
**Decision ref:** doc/tasks/0014-conservative-vocabulary.md
**Confidence:** Strong
**Stakes:** medium × reversible

## Decision and confidence

Use FluidAudio 0.18.3's per-term `minSimilarity` override rather than a second replacement engine. Its documented override applies to the primary and acoustic-rescue paths (A1), and upstream tests exercise candidate discovery and replay at this boundary (B1). Fala already constructs every configured vocabulary term in one store (C1). Its existing dictionary engine retains exact whole-term matching (C2). History establishes the current dictation thresholds and the once-only final correction path (D1). This defect correction deliberately reduces recovery of unlisted spelling mistakes; declared aliases remain available. No language-specific word list, manual context selection, model change or live-preference migration is required.

## Evidence

### E1 — The existing threshold permits rewriting an unlisted word

**Tier:** Measurement
**Strength:** High
**Provenance:** A1, B1, C1, D1

A deterministic SDK replay with synthetic CTC scores favoring a fictional canonical spelling changes base `aqui` through declared alias `Maqui`: similarity 0.8 passes the existing 0.7 threshold, with zero bias. Candidate evidence identifies the primary single-word path, including when acoustic rescue is disabled. This establishes a possible mechanism, not the source of any particular real recording. Reproduction uses `rtk bash scripts/swift-env.sh test --filter ConservativeVocabularyTests` with `FALA_RUN_VOCABULARY_REPLAY=1`, local cached CTC models, and no inference or downloads. The package identity is FluidAudio 0.18.3, revision c8b41f98eae668794dd0083bbe028fe7e6585051.

### E2 — Native exact similarity covers both candidate paths

**Tier:** Primary
**Strength:** Medium
**Provenance:** A1, B1, C1

The primary path reads the term override; rescue uses the maximum of that override and its rescue floor. Native-control replay with 1.0 preserves `aqui` while retaining declared aliases, case and terminal punctuation. The SDK also joins adjacent transcript tokens into a declared spelling; this is accepted segmentation normalization, not permission to invent or change letters. Consumer behavior tests must preserve words with extra prefix/suffix letters and unrelated sentence content even against adversarial synthetic acoustic scores.

### E3 — Final dictionary rules remain a distinct exact operation

**Tier:** Measurement
**Strength:** High
**Provenance:** C2, D1

The unchanged final rule engine preserved literal `aqui` in four case/punctuation/sentence fixtures and canonicalized all five explicit aliases in an isolated Foundation replay. Its source is identical to release v1.15. A correction here must affect recognition candidates rather than relax the final rule boundary.

## Source register

- **A1:** FluidAudio 0.18.3 API documentation and implementation, `CustomVocabularyContext.swift:18-25,44-57` and `VocabularyRescorer+TokenRescoring.swift:838,1358`, https://github.com/FluidInference/FluidAudio/blob/c8b41f98eae668794dd0083bbe028fe7e6585051/Sources/FluidAudio/ASR/Parakeet/SlidingWindow/CustomVocabulary/CustomVocabularyContext.swift (accessed 2026-11-11 via web and pinned local source).
- **B1:** FluidAudio 0.18.3 upstream replay reference, `VocabularyCandidateDiscoveryTests.swift`, https://github.com/FluidInference/FluidAudio/blob/c8b41f98eae668794dd0083bbe028fe7e6585051/Tests/FluidAudioTests/ASR/Parakeet/SlidingWindow/CustomVocabulary/VocabularyCandidateDiscoveryTests.swift (accessed 2026-11-11 via web and pinned local source).
- **C1:** Sources/FalaCore/Core/ParakeetVocabularyStore.swift:35, central native term construction; Tests/FalaTests/ParakeetVocabularyStoreTests.swift:70, declared alias preservation (accessed 2026-11-11 via source read).
- **C2:** Sources/FalaCore/Config/ReplacementRule.swift:14, one-pass whole-term replacement; Sources/FalaCore/Modes/DictationMode+Processing.swift:61, final rule application (accessed 2026-11-11 via source and isolated executable replay).
- **D1:** `git log --all --oneline -S vocabularyThresholds -- Sources/FalaCore/Core/ParakeetRuntimeManager.swift` identifies cc4a29f adding cbw 0/minSimilarity 0.7; e385ffe establishes bounded once-only final corrections. v1.14 and v1.15 contain the same thresholds (accessed 2026-11-11 via git).

## Limitations and reversal

Synthetic scores isolate consumer policy; they cannot identify what a base recognizer heard in an unavailable original recording. The correction does not resolve base recognizer mistakes that already equal declared aliases. Unlisted near-spellings cease to be recovered automatically; add an explicit alias where that recovery is intended. Reopen the decision if public deterministic fixtures show native 1.0 changing unlisted lexical letters or breaking declared forms. Do not add a custom range-splicing layer without that evidence.

## Audit path

Run `node /Users/ale/.agents/skills/ad-ground/scripts/validate-record.mjs doc/research/0029-ground-conservative-vocabulary.md`, then reopen the cited pinned sources. The structural validator does not prove source content.
