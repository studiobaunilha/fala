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

- [x] Record the focused ground, risks, migration contract, and evaluation alongside the implementation; link the resulting record from a dated Notes entry.
- [x] Add behavior tests for default migration, persistence, engine preservation, and model routing.
- [x] Add model selection to the existing adapters and settings; update the exact dependency only after compatibility checks.
- [x] Run focused tests, required local gates, and a packaged local smoke; obtain fresh-context review of the final delta.
- [x] Integrate through the orchestrator; retain v3 rollback and publish only after the release gates.

## Notes

- 2026-11-10 — Ultra selection/default, v3 rollback, dependency and notice changes are implemented and locally validated. Ultra author commit `8cff930d59d547e1d460b077c45da7b868c71190`, tree `819e32868881f161757e0b0cfd419420c1b015a4`, exact transported patch `8bc435306c638a63f4520ceb54786513b4bf7e602f9cde0cf55153a92622cf7d`; all 24 transported files compared byte-for-byte. The ground is recorded alongside the integration in git; no earlier planning-commit ancestry is claimed on this branch.
- Independent `/root/review_ultra` reviewed that patch/commit: “Revistos: migração/persistência, confirmação/cancelamento, ditado/aquecimento/lote/CLI, preservação de Whisper e caches, serialização, decoder state, vocabulário, traits, deployment target e avisos de terceiros.” Standards and Spec both “ship as-is”, zero findings. Runtime/gate/assembly evidence is separate from this source review.
- Final combined gate: `make check`, 191 Swift files strict lint with zero violations; 316 XCTest cases, two optional model cases skipped by default, zero failures. Both optional model integration cases separately executed with networking denied: two tests, zero skips, zero failures. Release 1.14/build35 packaged CLI additionally transcribed JFK offline with each selected model. Actual host: Apple M5 Pro, 48 GiB, arm64, macOS 27.2.1. These fixtures establish exercised routing and local functionality, not comparative transcription accuracy or performance.
- Compatibility limit: Swift package deployment target and built Mach-O minimum OS are 14.0; current FluidAudio traits exclude unused TTS/diarization components, and assembled notices match source. No macOS 14 runtime was available or tested. The combined compatibility criterion remains unchecked rather than claiming runtime coverage from metadata. A clean scratch resolution of the final manifest succeeded; the stale developer cache bootstrap needed a temporary manifest-only resolver workaround, restored byte-for-byte, with no remaining source workaround or other dependency pin changes.
- Developer ID signed app and DMG are staged locally in `.build/release-artifacts/1.14-input`, with source/input hashes and offline receipts under `.agentic/reviews/2026-11-10-*`. No installed app, tag, remote branch or public release was changed. Publication remains pending owner approval; this task is not closed.

- Independent integration audit at `c4e2d5bc54f57689be13bc4f4e0520dfd07af9af` (baseline CV.1→CV.8; gpt-6-astra in-host proxy CV.8→CV.1, not cross-provider) found an evidence blocker: CV.1/CV.5 critical, RN3 lacked an observed dictation insertion with both an active replacement and throwing AI. Both passes agreed. Remediation: a dedicated recorder/transcriber→insertion test now throws `LLMError` with configured name and chain rules; inserted text is corrected exactly once, clipboard fallback unchanged. Three dictation pipeline tests passed; no production changes. Delta audit remains pending.
- Baseline CV.5 open question: prior offline output logs did not retain the exact sandbox command. Remediation: a new execution wrapper retained argv, policy/hash, target, a limited fixture environment whitelist, return codes, two executed model cases and two packaged CLI transcript sinks. The same policy denied a localhost connection with PermissionError while an unsandboxed control connected; the new receipt reports new observations, not reconstructed historical commands. Production app/DMG bytes remain unchanged. Delta audit remains pending.
- Baseline CV.7 major concern: generic “before implementation” wording/checklists were not supported by the central commit ancestry. The cross-pass accepted the available author/integration ancestry, but the concern is conservatively remediated: wording now states only “recorded alongside”, without a before-work assertion or rewritten history. Delta audit remains pending. Baseline CV.2/CV.3/CV.6/CV.8 passed; CV.4 did not claim a deployed fix. Cross-pass had no other findings. The separate HK audit closed HK.1 with actual canonical commit execution and HK.2 as N/A; no hooks changed during remediation.

- 2026-11-10 — Published Fala 1.14/build35 from source `fdcc5469aa7dcff2f88f54136d6e146372850cb0` under immutable signed tag `v1.14` (tag object `e1e91f2b83aa374b8ca3cde0d5a400ab82bb9206`, SSH signature verified). Public versioned download: https://pub-e4238720a12f45f68eff0a79f3dda647.r2.dev/Fala-1.14.dmg; latest: https://pub-e4238720a12f45f68eff0a79f3dda647.r2.dev/Fala-latest.dmg; updater feed: https://pub-e4238720a12f45f68eff0a79f3dda647.r2.dev/appcast.xml. Readback verified both DMG downloads against SHA256 `c9ca0e6608b78db94fd549ce6eef11b7805869ea94415d60063895527cb1aecc`, 19199639 bytes, and the feed against SHA256 `d250018ed56ecb3aaa3f91fa02d54ed91acd58e70b84b67199302fb786e6be2e`. Sparkle signatures on both public downloads verified against the installed application's public key. The installed application was not changed. Publication receipt: `.build/release-artifacts/1.14/publication-final.json` (local operational record).
- Final independent integration delta audits at `fdcc5469aa7dcff2f88f54136d6e146372850cb0`: baseline gpt-6.1-sol and gpt-6-astra in-host proxy report no findings; all eight CV rules accounted. Earlier F1 (CV.1/CV.5 active-rule AI-failure sink), F2 (CV.5 offline invocation evidence) and F3 (CV.7 generic temporal wording) are resolved by the observed test, recorded execution wrapper and narrowed wording respectively. HK.1 passed and HK.2 was N/A; source/gate coverage remained closed. The real process-checker FAIL was retained; publication used an explicitly approved host-recognition exception limited to this delivery's native Codex evidence. No checker was changed or PASS fabricated.
- Release milestone published. Task remains in-progress solely for the unverified macOS14 runtime portion of the compatibility criterion; deployment/Mach-O minimum14.0 are measured, but are not runtime testing. No source/model/version change is pending for the published milestone. Earlier publication/audit-pending entries are superseded by this record.

## Definition of Done

All Acceptance Criteria checked, plus:

- [x] Local tests pass (or N/A documented in Notes)
- [x] Code review completed (human or fresh-context reviewer per WORKFLOW §10)
- [x] No orphan `TODO`/`FIXME` introduced
- [ ] Status updated to `done` and Notes log closes the task
