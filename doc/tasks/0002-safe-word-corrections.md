# Task 0002: Apply literal corrections without corrupting other words

**Status:** in-progress
**Created:** 2026-11-10
**Scope ref:** README.md
**Evidence ref:** doc/research/0007-ground-word-corrections.md
**Owner:** replacement_delivery
**Execution:** AFK
**Spec ref:**
**Board ref:**

## Context

A name correction must not rewrite a matching sequence inside an unrelated word. The regression fixture is `Nico → Niko`: an isolated name changes, while `comunico` remains intact. This slice also keeps learned corrections from combining unrelated edits into one destructive rule.

## Acceptance Criteria

- [x] The literal rule `Nico → Niko` matches the isolated name case-insensitively and preserves `comunico`, `econômico`, and `Nicolas`.
- [x] Word boundaries handle Unicode letters, combining marks, adjacent punctuation, and phrase rules with deterministic tests.
- [x] Longer matching names or phrases win overlaps; replacement output is not processed again by another literal rule in the same pass.
- [x] Legacy saved rules retain their identifiers, patterns, and replacement content through load/save.
- [x] Correction learning does not merge separated edits into a single learned phrase or discard punctuation from a learned edit.
- [x] The shared correction path is verified for dictation and file transcription, independently of ASR output.

## Plan

- [x] Record the reproduced literal-replacement failure, diagnosis, four-source ground, and evaluation alongside the implementation.
- [x] Write regression tests through the rule application and learning interfaces.
- [x] Use the existing Foundation/Unicode facilities to implement bounded, non-cascading literal matching; preserve existing configuration structure.
- [x] Run focused tests and local gates; obtain fresh-context review of the final delta and integrate through the orchestrator.

## Notes

- 2026-11-10 — Local implementation and assembly verified; publication remains pending owner approval. All literal matching, legacy persistence, learner replay and final dictation/file-window criteria are covered. Ground and plan are recorded alongside the implementation in git; no earlier planning-commit ancestry is claimed.
- Independent `/root/review_corrections` reviewed original patch `165133b8cc00202aced40d723de64d8c7e18a38e9508ff0239bdb0b50a319369`: Standards “ship as-is”; Spec Blocker: “o aprendizado ainda perde pontuação nas extremidades do trecho: `Use c mais hoje` → `Use C++ hoje` aprende `c mais` → `C`”. Disposition: replay guard rejects a learned rule unless it recreates the complete edited text; C++ regression observed RED→GREEN.
- Independent delta verdict for `c6f9b85636e28777b865e13ae18d5421bd90d27efc42d9d56459e5755e8c34d0` (integral patch `ea4649d1bba44a3223293f88ad8683f8c35dcb86cdf873e29def13b387f7c98b`): “Blocker anterior resolvido”; Standards and Spec “ship as-is”, zero findings. The delta also covers the final dictation output once after AI/raw/fallback; 49 selected tests passed.
- Integration found the corresponding confirmed-file-window AI path still corrected before AI. A real adapter fixture reproduced the wrong name at both returned outcome and saved TXT. The pass now runs once on the final outcome, preserving warnings. Four new regressions cover successful AI, echo without cascading, raw output and error fallback. Independent delta review of `ae7af61605f6bef2a2137d53b8e457eabb2a738dad4201f0b64f7ce38e2881fe`: “Registros confirmam falha anterior no retorno e TXT, seguida de 23 testes passando”; Standards and Spec “ship as-is”, zero findings.
- Final combined `make check`: 316 XCTest cases, two optional model cases skipped by default, zero failures; strict lint 191 Swift files, zero violations. The two optional cases separately ran with networking denied and passed (zero skips); both Ultra and v3 exercised JFK and the controlled vocabulary fixture. Release 1.14/build35 app assembled and Developer ID signed locally; packaged CLI Ultra/v3 each transcribed JFK offline. No installed app was changed. CLI's pre-existing raw transcript contract is unchanged.
- Reproduction, commands, source/input hashes, exact independent verdicts and assembly receipts are retained under `.agentic/reviews/2026-11-10-*`; final compiled input freeze index tree `df342ac15d41d7393890b6c4ad15d6d78f9d8487`. These are local assembly results, not evidence of a published release.

- Independent integration audit at `c4e2d5bc54f57689be13bc4f4e0520dfd07af9af` (baseline CV.1→CV.8; gpt-6-astra in-host proxy CV.8→CV.1, not cross-provider) found an evidence blocker: CV.1/CV.5 critical, RN3 lacked an observed dictation insertion with both an active replacement and throwing AI. Both passes agreed. Remediation: a dedicated recorder/transcriber→insertion test now throws `LLMError` with configured name and chain rules; inserted text is corrected exactly once, clipboard fallback unchanged. Three dictation pipeline tests passed; no production changes. Delta audit remains pending.
- Baseline CV.5 open question: prior offline output logs did not retain the exact sandbox command. Remediation: a new execution wrapper retained argv, policy/hash, target, a limited fixture environment whitelist, return codes, two executed model cases and two packaged CLI transcript sinks. The same policy denied a localhost connection with PermissionError while an unsandboxed control connected; the new receipt reports new observations, not reconstructed historical commands. Production app/DMG bytes remain unchanged. Delta audit remains pending.
- Baseline CV.7 major concern: generic “before implementation” wording/checklists were not supported by the central commit ancestry. The cross-pass accepted the available author/integration ancestry, but the concern is conservatively remediated: wording now states only “recorded alongside”, without a before-work assertion or rewritten history. Delta audit remains pending. Baseline CV.2/CV.3/CV.6/CV.8 passed; CV.4 did not claim a deployed fix. Cross-pass had no other findings. The separate HK audit closed HK.1 with actual canonical commit execution and HK.2 as N/A; no hooks changed during remediation.

## Definition of Done

All Acceptance Criteria checked, plus:

- [x] Local tests pass (or N/A documented in Notes)
- [x] Code review completed (human or fresh-context reviewer per WORKFLOW §10)
- [x] No orphan `TODO`/`FIXME` introduced
- [ ] Status updated to `done` and Notes log closes the task
