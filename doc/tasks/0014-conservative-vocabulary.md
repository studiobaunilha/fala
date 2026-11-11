# Task 0014: Preserve undeclared transcript words

**Status:** in progress
**Created:** 2026-11-11
**Owner:** vocabulary defect delivery role
**Execution:** AFK
**Scope ref:** README.md
**Evidence ref:** doc/research/0029-ground-conservative-vocabulary.md

## Context

Configured vocabulary aliases can authorize approximate recognition corrections to ordinary words that were never declared. Correct the default policy without requiring manual contexts or changing saved preferences. This is a defect correction to existing local transcription.

## Acceptance Criteria

- [x] Adversarial synthetic CTC replay preserves unlisted words and sentence content under the actual consumer vocabulary configuration.
- [x] Declared aliases, canonical spelling, case, punctuation and native word segmentation remain available with sufficient acoustic evidence.
- [x] Prefix/suffix words and undeclared letter changes are preserved; no language-specific protected-word list is introduced.
- [x] Default tests require no models, network, microphone or live preferences; opt-in SDK replay loads cached models only and performs no inference.
- [ ] Focused tests and independent review cover the final source state before release.

## Plan

- [x] Reproduce the SDK policy failure, distinguish final exact replacement from vocabulary recognition, compare native controls and record four-source grounding.
- [x] Add a failing consumer replay and permanent model-free safeguards, apply the smallest native policy correction, rerun targeted checks.
- [ ] Hand the bounded diff and evidence to the release owner for independent review and applicable integration gates.

## Notes

- 2026-11-11 — Ranked hypotheses: H1 vocabulary rescoring rewrites an undeclared base word; H2 base recognizer already emits a declared alias; H3 LLM introduces it; H4 final dictionary directly matches it. Isolated exact-rule replay refutes H4 for literal input; selected raw mode excludes H3. Synthetic SDK replay supports H1 via primary term-centric matching at similarity 0.8 despite cbw 0 and minimum 0.7; rescue-off does not prevent it. H2 remains unresolved for unavailable original audio. Native per-term 1.0 blocks undeclared letter edits while preserving declared spelling and SDK segmentation normalization. No live app or settings changed.
- 2026-11-11 — Consumer TDD: three new tests fail before the patch (five failures, including literal/sentence rewrites and the two term-construction assertions). The store now supplies native per-term similarity 1.0. Focused run passes 33 tests with zero failures; the opt-in SDK replay executes 40 synthetic case/configuration combinations in 1.024 seconds. It covers ordinary words, case, punctuation, prefix/suffix boundaries, declared short and multiword aliases, NFC/NFD, canonical output and native segmentation with rescue enabled and disabled. Default replay stays opt-in, requiring cached models without download or inference. Logs: `.build/conservative-vocabulary-red.log`, `.build/conservative-vocabulary-green.log`, `.build/conservative-vocabulary-default-green.log`; source/log hashes and command receipts: `.agentic/reviews/conservative-vocabulary-worker.json`. Independent review and assembled release gates remain with the release owner. No installation, publication or original-audio reproduction is claimed.

## Definition of Done

- [ ] Acceptance criteria verified with source and execution evidence.
- [ ] Independent review and applicable local gates closed on the final state.
- [ ] Remaining limitations and release ownership documented; no claim of original-audio reproduction or installation without observation.
