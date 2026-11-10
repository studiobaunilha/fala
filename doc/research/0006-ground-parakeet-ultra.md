# GROUND-0006: Reversible Parakeet Ultra selection

**Status:** recorded
**Decision:** Add an explicit Ultra/v3 model choice, default to Ultra when absent, retain Whisper and both Parakeet caches, and pin FluidAudio 0.18.3 with ASR-only traits.
**Decision ref:** doc/tasks/0001-selectable-parakeet-ultra.md (central integration checkout)
**Confidence:** Strong
**Stakes:** medium × reversible

## Decision and confidence

The owner has selected Ultra as the new default while retaining previous models. Extend the existing configuration and confirmed-restart settings flow rather than encode model variants as new transcription engines. Use FluidAudio's public AsrModels, AsrManager and VocabularyBoostingSession APIs. Sources A1/B1 support Ultra's model contract, C1 provides the current adapter seam, and D1 establishes the concurrency safeguard that must survive. Strong confidence applies to the implementation path, not to a claim of better Portuguese accuracy. The first real inference run is a compatibility gate, not a model-quality comparison.

## Evidence

### E1 — Ultra preserves the v3-family model contract

**Tier:** Primary
**Strength:** Medium
**Provenance:** A1, B1

The pinned library documents Ultra with the same 25 languages/tokenizer and macOS 14 requirement. Its example is `AsrModels.downloadAndLoad(version: .ultra)`. The dependency's newer API requires loadModels and a per-request decoder state; blindly changing `.v3` would not compile. Provider accuracy figures are not local measurements.

### E2 — Keep vocabulary using the upstream acoustic rescorer

**Tier:** Primary
**Strength:** Medium
**Provenance:** A2, B2, C1, D1

The newer batch AsrManager no longer exposes the old configureVocabularyBoosting entry point. Its public VocabularyBoostingSession performs rescoring from text, token timings and the same audio. Preserve the app's serialized operations and wrap that public session instead of implementing phonetic matching. Configuration errors keep the existing graceful path of unboosted transcription; failure to load the chosen ASR model remains an error, not a silent model substitution.

### E3 — Isolate configuration and optional dependency subsystems

**Tier:** Primary
**Strength:** Medium
**Provenance:** A3, C2, C3

FluidAudio 0.18.3's Swift 6.2 manifest supports disabling TTS, Diarizer and NemoTextProcessing traits. The Fala checkout imports only ASR/vocabulary types. Raising the build-tools declaration to Swift 6.2 permits explicitly opting out of unused subsystems; deployment remains macOS 14. No unrelated dependency update is intended. The exact dependency composition and license notices must be inspected after resolution. The documented dictation thresholds `cbw: 0, minSimilarity: 0.7` will be used to require stronger acoustic evidence; these are an upstream preset, not a locally optimized batch threshold.

## Implementation plan

Approved direction: Ultra default and reversible selection. This record fixes the implementation contract before production edits.

1. Add a typed Ultra/v3 choice stored independently from transcriptionEngine. Missing/invalid choice resolves to Ultra; a valid explicit v3/Ultra survives JSON round trips. Existing Whisper engine choices remain unchanged.
2. Propagate the choice through dictation, warmup, batch GUI factories and CLI. A settings change saves only after restart confirmation; cancellation leaves the selection unchanged. Existing cached models are not removed.
3. Pin FluidAudio 0.18.3, disable unused traits with the Swift 6.2 manifest, adapt its public batch and vocabulary session APIs behind the existing ParakeetRuntimeManaging seam.
4. Add CLI `--parakeet-model ultra|v3` as a per-invocation override without modifying stored configuration; retain the Whisper `--model` flag and reject invalid Parakeet names. Add the visible choice and truthful labels in the four app languages, update required third-party notices/attribution, and avoid performance claims unsupported by measurements.
5. Run the frozen checks below, then request independent review of this delta. No push, app installation, tag, or release from this worktree.

## Preregistered evaluation

The decision is implementation compatibility, not which model is more accurate. Freeze before the first deciding run:

| Risk | Observable check | Pass condition |
|---|---|---|
| Wrong default or broken rollback | Config decode/round-trip tests | New/legacy missing model → Ultra; v3 and Whisper choices preserved |
| Settings lie about active model | Restart-confirmation/cancellation tests and settings snapshot | Confirmed model persisted; canceled unchanged; selected labels match |
| Inconsistent dictation/batch | Shared selection factory tests and assembled CLI smoke | Both versions resolvable through the same selection; actual chosen Ultra transcribes public audio |
| Lost vocabulary | Existing ParakeetTranscriber tests, new upstream integration smoke | Configuration, failure fallback and disable paths preserved; configured inference completes |
| Dependency regression | Strict lint, unit suite, app bundle build | All required checks pass; no skipped hooks or tests |
| License/OS regression | Manifest and embedded notices readback | Deployment target remains14; notices correspond to linked components; no unnecessary TTS/diarizer binary |
| Silent model substitution | Runtime selection mapping and load failure checks | Selected model loaded or its error returned; no hidden fallback |

Machine observed before download: Apple Silicon, macOS27.2.1, 48GiB memory and223GiB free. No claim of executed macOS14 coverage: only declared deployment compatibility can be checked on this host. Public JFK fixture may be reused as a smoke test, not a Portuguese-quality benchmark. A separate local synthetic fixture, generated with the installed macOS Luciana pt-BR voice, will exercise the literal sentence "Eu me comunico com o Nico todos os dias." with the controlled term Niko/alias Nico. Pass requires retaining the complete word comunico and not producing a substring corruption; the name result is recorded, without claiming a human-speech benchmark. Both models and the conservative preset are checked before exposure. Stop on compile/runtime incompatibility; record diagnosis before changing the contract. No private audio or paid inference.

## Source register

- **A1:** https://raw.githubusercontent.com/FluidInference/FluidAudio/v0.17.3/Documentation/ASR/ParakeetUltra.md, Ultra/v3 contract and OS table (accessed 2026-11-10 via web)
- **A2:** FluidInference/FluidAudio v0.18.3 `Sources/FluidAudio/ASR/Parakeet/SlidingWindow/CustomVocabulary/VocabularyBoostingSession.swift:90–240`, public session and rescoring API, clone SHA c8b41f98eae668794dd0083bbe028fe7e6585051 (accessed 2026-11-10 via HTTPS git clone)
- **A3:** https://raw.githubusercontent.com/FluidInference/FluidAudio/v0.18.3/Package@swift-6.2.swift, platform and optional traits (accessed 2026-11-10 via HTTPS git clone)
- **B1:** FluidInference/FluidAudio v0.18.3 `README.md:355–375`, loadModels/transcribe example, same pinned clone (accessed 2026-11-10 via local read of HTTPS clone)
- **B2:** FluidInference/FluidAudio v0.18.3 `Sources/FluidAudio/ASR/Parakeet/SlidingWindow/SlidingWindowAsrManager.swift:178–195`, constructs VocabularyBoostingSession; `Sources/FluidAudio/ASR/Parakeet/SlidingWindow/TDT/AsrManager.swift:535`, explicit decoder state (accessed 2026-11-10 via local read of HTTPS clone)
- **C1:** `Sources/FalaCore/Core/ParakeetRuntimeManager.swift:17–69`, serialized adapter; `Sources/FalaCore/Core/ParakeetTranscriber.swift:117`, vocabulary lifecycle (accessed 2026-11-10 via local read)
- **C2:** `Sources/FalaCore/Config/AppConfig.swift:11,194` and `Sources/FalaCore/UI/AppSettings.swift:291`, config migration and restart selection (accessed 2026-11-10 via local read)
- **C3:** `rg 'import FluidAudio|Diarizer|Sortformer' Sources` finds only Parakeet runtime/store imports; Package.swift deployment14 (accessed 2026-11-10 via local command)
- **D1:** `git log main --oneline -- Sources/FalaCore/Core/ParakeetRuntimeManager.swift`: e7ce8a5 serializes vocabulary access; `git branch -a` and `git worktree list` identify isolated codex/fala-ultra and the separate unmodified original checkout (accessed 2026-11-10 via git)

## Limitations and reversal

No Portuguese accuracy, battery or long-file performance conclusion follows from this plan. A real SDK incompatibility, missing model artifact, required unsupported license, or failed regression gate blocks exposure and reopens this implementation choice. The old models remain user-selectable regardless of benchmark results.

## Audit path

Run `node /Users/ale/.agents/skills/ad-ground/scripts/validate-record.mjs doc/research/0006-ground-parakeet-ultra.md`. Reopen the pinned clone and source locations; schema validity is not empirical compatibility evidence. Raw execution logs live under ignored `.agentic/reviews/`.
