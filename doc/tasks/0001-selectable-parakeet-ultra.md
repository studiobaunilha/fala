# Task 0001: Add selectable Parakeet Ultra as the default

**Status:** in-progress
**Created:** 2026-11-10
**Scope ref:** README.md
**Evidence ref:** doc/research/0006-ground-parakeet-ultra.md
**Owner:** ultra_delivery
**Execution:** AFK
**Spec ref:**
**Board ref:**

## Context

Users need a newer local speech model without losing access to the previous working model. This slice adds Ultra beside v3 and preserves Whisper as a separate engine. The requested default is Ultra; changing the default does not establish a measured accuracy advantage.

## Acceptance Criteria

- [x] New configurations and existing configurations without an explicit Parakeet-model choice resolve to Ultra; an explicitly selected Whisper engine remains Whisper.
- [x] Settings expose Ultra and v3; either explicit choice survives save/reload and the existing confirm/cancel restart flow.
- [x] Dictation, prewarming, GUI file transcription, and CLI transcription use the selected Parakeet model consistently.
- [x] Switching back to v3 leaves its existing cached model available; no automatic cache deletion occurs.
- [x] Model-download failures are reported rather than silently substituting another model.
- [ ] Vocabulary support and serialized access remain covered; macOS 14 compatibility and notices for newly linked components are verified.
- [x] A packaged local transcription succeeds with the selected candidate, with the actual model and hardware recorded; no unmeasured performance claim is added.

## Plan

- [x] Record the focused ground, risks, migration contract, and evaluation before implementation; link the resulting record from a dated Notes entry.
- [x] Add behavior tests for default migration, persistence, engine preservation, and model routing.
- [x] Add model selection to the existing adapters and settings; update the exact dependency only after compatibility checks.
- [x] Run focused tests, required local gates, and a packaged local smoke; obtain fresh-context review of the final delta.
- [ ] Integrate through the orchestrator; retain v3 rollback and publish only after the release gates.

## Notes

- 2026-11-10 — Ultra selection/default, v3 rollback, dependency and notice changes are implemented and locally validated. Ultra author commit `8cff930d59d547e1d460b077c45da7b868c71190`, tree `819e32868881f161757e0b0cfd419420c1b015a4`, exact transported patch `8bc435306c638a63f4520ceb54786513b4bf7e602f9cde0cf55153a92622cf7d`; all 24 transported files compared byte-for-byte. Ground captured on disk before implementation is recorded alongside the integration in git; no earlier planning-commit ancestry is claimed on this branch.
- Independent `/root/review_ultra` reviewed that patch/commit: “Revistos: migração/persistência, confirmação/cancelamento, ditado/aquecimento/lote/CLI, preservação de Whisper e caches, serialização, decoder state, vocabulário, traits, deployment target e avisos de terceiros.” Standards and Spec both “ship as-is”, zero findings. Runtime/gate/assembly evidence is separate from this source review.
- Final combined gate: `make check`, 191 Swift files strict lint with zero violations; 316 XCTest cases, two optional model cases skipped by default, zero failures. Both optional model integration cases separately executed with networking denied: two tests, zero skips, zero failures. Release 1.14/build35 packaged CLI additionally transcribed JFK offline with each selected model. Actual host: Apple M5 Pro, 48 GiB, arm64, macOS 27.2.1. These fixtures establish exercised routing and local functionality, not comparative transcription accuracy or performance.
- Compatibility limit: Swift package deployment target and built Mach-O minimum OS are 14.0; current FluidAudio traits exclude unused TTS/diarization components, and assembled notices match source. No macOS 14 runtime was available or tested. The combined compatibility criterion remains unchecked rather than claiming runtime coverage from metadata. A clean scratch resolution of the final manifest succeeded; the stale developer cache bootstrap needed a temporary manifest-only resolver workaround, restored byte-for-byte, with no remaining source workaround or other dependency pin changes.
- Developer ID signed app and DMG are staged locally in `.build/release-artifacts/1.14-input`, with source/input hashes and offline receipts under `.agentic/reviews/2026-11-10-*`. No installed app, tag, remote branch or public release was changed. Publication remains pending owner approval; this task is not closed.

## Definition of Done

All Acceptance Criteria checked, plus:

- [x] Local tests pass (or N/A documented in Notes)
- [x] Code review completed (human or fresh-context reviewer per WORKFLOW §10)
- [x] No orphan `TODO`/`FIXME` introduced
- [ ] Status updated to `done` and Notes log closes the task
