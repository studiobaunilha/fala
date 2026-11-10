# GROUND-0007: Whole-term corrections without destructive substitutions

**Status:** recorded
**Decision:** Match literal, case-insensitive terms at Unicode word boundaries against the original input; prefer the longest overlapping term, and emit each replacement once. Learn only one contiguous edited phrase, preserving its actual spelling and punctuation.
**Decision ref:** doc/tasks/0002-safe-word-corrections.md
**Confidence:** Strong
**Stakes:** medium × reversible

## Decision and confidence

The existing public replacement API is the right seam: it is shared by dictation and batch transcription (C1). Foundation canonical literal search plus standard Unicode word-continuation checks preserve accents and prevent intraword changes (A1–A2). VoiceInk provides a concrete precedent for boundary-aware literal replacements and longer-phrase priority (B1). Keep the Codable schema and IDs unchanged (D1). Build output from original matches so neither rule ordering nor generated output creates cascades. This is a correction to existing behavior, with the direction authorized before implementation; it introduces no new model, service or UI mode.

## Evidence

### E1 — The corruption is deterministic after recognition

**Tier:** Measurement
**Strength:** High
**Provenance:** C1, D1

A Foundation-only executable assembled from the actual `ReplacementRule.swift` evaluates Nico→Niko on `Eu comunico com Nico` as `Eu comuNiko com Niko`, failing the expected literal `Eu comunico com Niko` with exit 1. No microphone, ASR runtime or model participates. Command: `swift .context/repro.swift`; the script appends only the input and assertion to the unmodified source. This proves one sufficient cause; it does not claim that ASR boosting can never make a separate mistake.

### E2 — Word-aware literal matching is the canonical repair

**Tier:** Primary
**Strength:** Medium
**Provenance:** A1, A2, B1, C1

ICU defines word characters to include letters, marks, numbers, connector punctuation and join controls. The reference application uses escaped literal patterns with Unicode boundary guards and prioritizes longer variants. Foundation literal search retains canonical equivalence, unlike direct ICU regex literal matching for composed/decomposed accents (measured locally: NSString case-insensitive search finds decomposed é at UTF-16 range {0,2}; an ICU regex literal é does not). Therefore match canonically using NSString and apply boundary guards to original Unicode scalars. Do not interpret replacement syntax or `$1` as templates. No custom tokenizer or dependency is needed, and no reference source code is copied.

### E3 — The existing learning path loses source fidelity

**Tier:** Primary
**Strength:** Medium
**Provenance:** C2, D2

The learner joins changed tokens with spaces, ignoring punctuation between them, and can join two separated edits into a single rule. Retain original token ranges and reject a changed span with an unchanged token inside. Pure punctuation edits and insertion/deletion remain excluded. This conservative condition prevents automatic rules inferred from a rewrite while retaining short corrections.

### E4 — A final correction pass prevents successful AI output from discarding rules

**Tier:** Measurement
**Strength:** High
**Provenance:** B2, C3, D3

A real package test drives the DictationMode recorder/transcriber/AI/inserter sequence with a tone WAV and injected provider. Input `Eu comunico com Nico`, rule Nico→Niko and an AI result `Eu comunico com Nico.` insert the uncorrected name: exact expected output `Eu comunico com Niko.` fails. The reference product documents after-AI replacements for final formatting (B2). Apply the existing rules once to the final result, shared by raw, AI success and error fallback; applying both before and after would cascade A→B→C even for an echo provider. No timing option or additional settings are introduced. This extends the implementation path to the user-visible insertion seam; it does not claim accuracy of an actual model.

## Diagnosis and frozen evaluation

Feedback loop: execute the existing XCTest cases plus a new regression case using the actual three Foundation-only production files and test classes, assembled into a temporary XCTest runner. This avoids loading transcription frameworks for each TDD cycle; the package gate will run after coordination grants its heavy slot.

Ranked hypotheses, before probing:

1. Literal substring substitution causes intraword mutation. Prediction: the pure replacement API reproduces `comuNiko` without ASR. Confirmed by E1.
2. ASR vocabulary boosting is the necessary cause. Prediction: no corruption through the pure API. Falsified as a necessary explanation by E1; independent acoustic mistakes remain outside this claim.
3. Learned partial variants create the corruption. Prediction: only learned/imported rules reproduce it. Falsified for this case: a fresh explicit full-name rule reproduces E1.

Contract, fixed before production changes:

- `Eu comunico com Nico` → `Eu comunico com Niko`; larger Unicode words, combining marks, digits and identifiers are protected.
- Preserve explicit replacement casing, literal symbols, accents/canonical equivalence, punctuation outside matches, multiple occurrences and phrases.
- Prefer longest term at an overlapping original position, stable configured order for identical matches; do not rematch inserted output.
- Existing JSON decodes and encodes without schema/id loss. Empty variants do nothing. No regex/substring user-selectable mode exists to preserve.
- Learned phrase punctuation comes from actual edited ranges; two independent edits separated by an unchanged word do not become one rule. Changes unrelated to the inserted text remain rejected.

Go/no-go: exact output equality for every regression, all prior focused cases pass, strict lint passes, and the full package tests pass before integration. No benchmark claim or statistical accuracy claim is made.

Risks and retirement: Unicode/range corruption → composed/decomposed accents and emoji regression; ambiguous overlap → longest-match and stable-tie tests; template injection → literal metacharacter test; legacy migration → Codable round-trip; over-learning → separated-change and actual-span tests; ASR uncertainty → do not claim acoustic validation from string tests.

Implementation sequence: establish green focused baseline; add the Nico regression and observe red; minimal boundary fix and green; add noncascading/overlap behaviors incrementally; then learning fixes one behavior at a time. Independent review and assembled-path/package verification follow before exposure. No push or release is authorized to this worker.

## Execution evidence

The focused runner compiles the actual Foundation-only production files and XCTest classes with XCTestSuite discovery, without importing transcription frameworks. The 21 existing cases passed before changes. Nico intraword replacement, cascading output, shorter-term precedence, lost learned punctuation, separated edits, decomposed learner marks and whitespace-only variants each had an observed failing regression before their fix. Final focused run: 33 tests, zero failures. Strict lint of the four changed Swift files: zero violations. Full package and packaged-app checks remain integration gates, not claimed by these string tests. Receipts are under `.agentic/reviews/corrections-*.log`; runner source is `.context/run-correction-tests.py`.

The independent reviewer reported a lossy learned-term blocker (c mais→C++ becomes c mais→C). The added regression failed before the guard and passed after requiring exact replay of the edited text;34focused cases then passed. Actual package dictation pipeline tests reproduced successful-AI correction loss before changing the processing phase. The corrected path applies rules once at final output, including raw/error fallback. Final selected package run:49tests,0failures, including the successful-AI and echo/no-cascade tracers plus existing DictationMode cases. Strict lint of all six changed Swift files passed. Full package suite remains an integration gate. Detailed independent verdict is retained by the coordinating session; this paragraph records the implementer disposition, not a second independent review.

## Source register

- **A1:** https://developer.apple.com/documentation/foundation/nsstring/range(of:options:range:locale:) and https://developer.apple.com/documentation/foundation/nsregularexpression (accessed 2026-11-10 via web; Foundation search and literal escaping APIs).
- **A2:** https://unicode-org.github.io/icu/userguide/strings/regexp.html sections Word characters, Case Insensitive Matching and Find and Replace (accessed 2026-11-10 via web; Unicode properties and replacement-template hazards).
- **B1:** Beingpax/VoiceInk `VoiceInk/Features/Dictionary/Workflows/WordReplacementService.swift:117–143`, obtained from https://raw.githubusercontent.com/Beingpax/VoiceInk/main/VoiceInk/Features/Dictionary/Workflows/WordReplacementService.swift (accessed 2026-11-10 via HTTPS and web). Relevant quoted API: `NSRegularExpression.escapedPattern(for: rule.original)`. Product semantics: https://tryvoiceink.com/docs/word-replacements (accessed 2026-11-10 via web).
- **C1:** `Sources/FalaCore/Config/ReplacementRule.swift:15`; `Sources/FalaCore/Modes/DictationMode+Processing.swift:19`; `Sources/FalaCore/UI/TranscriptionJob+Processing.swift:210,323`; `Tests/FalaTests/ReplacementRuleSetTests.swift` (accessed 2026-11-10 via local read).
- **C2:** `Sources/FalaCore/Core/CorrectionLearningAnalyzer.swift:37–77`; `Tests/FalaTests/CorrectionLearningAnalyzerTests.swift`; `Sources/FalaCore/UI/InsertionReviewController.swift:132` (accessed 2026-11-10 via local read).
- **D1:** `git log HEAD --oneline --grep='replacement\|correction\|vocabulary'`: `5e4f431` multi-variant schema migration; `1162b7b` centralized rule management; `6a92de0` extraction to reduce file length (accessed 2026-11-10 via Git).
- **D2:** `git log HEAD --oneline -- Sources/FalaCore/Core/CorrectionLearningAnalyzer.swift`; `145f3aa` manual-edit learning, followed by `bc7af86` extraction; `git branch -a` includes main and separate codex worktrees Automated checkpoints were not used as product decisions (accessed 2026-11-10 via Git).

- **B2:** https://spokenly.app/docs/word-replacements, Timing (Before/After AI) section; quoted label `Run After AI Instructions` describes replacements applied to AI output (accessed 2026-11-10 via web).
- **C3:** `Sources/FalaCore/Modes/DictationMode+Processing.swift:19,34,61`; the previous code computed fallback corrections then returned uncorrected AI output; `Tests/FalaTests/DictationModeTests.swift:211` demonstrates injected LLM errors through the same interface (accessed 2026-11-10 via local read).
- **D3:** `git log HEAD --oneline -- Sources/FalaCore/Modes/DictationMode+Processing.swift`: `232442f` introduced the current processing flow (accessed 2026-11-10 via Git).

## Limitations and reversal

This fixes text processing, not phonetic recognition or context-sensitive homonyms. Whole-term guards are conservative for continuous scripts: no new language segmentation engine is claimed. No new automatic rewrite is learned from a large or multi-edit sentence. Existing user rules are retained rather than silently deleted. Explicit future requirements for substring/regex modes would need their own design.

## Audit path

Run `node /Users/ale/.agents/skills/ad-ground/scripts/validate-record.mjs doc/research/0007-ground-word-corrections.md`, then reopen cited source files and primary references. Test receipts live in ignored `.agentic/reviews/`.

## Integration follow-up: confirmed file windows after AI

The combined release check traced `TranscriptionJob.processConfirmedWindowText` and found that replacements ran before AI while the resulting text was written directly. The same final-output contract already chosen for dictation applies to confirmed file windows; live preview remains a separate rendering of raw ASR progress. A local `URLProtocol` fixture exercises the real AI adapter and file append boundary without a remote request. Before the fix, the successful-AI case returned and saved `Nico` rather than `Niko`; the raw, fallback and echo controls passed. Moving the existing replacement pass to the final outcome preserves warning propagation and avoids applying rules before and after AI. No new timing option or CLI behavior is introduced.

Evidence: `2026-11-10-batch-replacement-red.log` (4 tests, 2 assertions fail in the same successful-AI case, 0 unexpected); `2026-11-10-batch-replacement-green.log` (23 focused tests, 0 failures). Source-kit tooling requires the canonical `DEVELOPER_DIR`; invoking lint without it failed at tool loading, then the canonical environment completed strict lint. The first HTTP fixture omitted a response header callback and trapped Foundation; that harness defect was fixed before the recorded behavioral RED run.
