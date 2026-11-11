# Spec 0002: Select a manual vocabulary context

**Status:** draft
**Created:** 2026-11-10
**Owner:** contexts delivery role

## Context

People dictate different names and specialist terms at home, at work and within projects. One undifferentiated list makes unrelated names compete. Fala already has local Parakeet vocabulary rescoring; this slice exposes manually managed context collections without collecting private background information. The owner authorized implementation and release of the bounded improvement; routine defaults below require no further interview.

## User Scenarios

- Given existing settings, when upgrading with Contexts disabled, then current global vocabulary and replacement behavior remain unchanged.
- Given enabled Contexts and two named collections, when selecting Work and beginning a recording, then only Work vocabulary guides that recording even if the selected collection is edited or changed before transcription finishes.
- Given selected Work, when starting a file queue, then every item in that run uses its initial Work snapshot; the next run uses the latest selection.
- Given a selected profile is deleted, when starting another operation, then Default is selected and displayed; already running work keeps its snapshot.
- Given Whisper is active, when viewing Contexts, then the interface explains that vocabulary contexts require Parakeet and does not silently change engines or claim Whisper conditioning.

## Requirements

### Functional

- R1: Add a persisted opt-in Contexts switch, false for missing/legacy configuration. Default remains available and cannot be deleted. With the switch off, resolve the exact existing global `parakeetVocabularyStore` behavior.
- R2: Named contexts have stable identifiers, a trimmed nonempty name and terms containing preferred spelling plus zero or more aliases. Support create, rename, delete, add/remove term and edit aliases through native controls. Reject empty names/terms and duplicate names case-insensitively. Existing store normalization handles repeated terms/aliases.
- R3: Default resolves existing explicit global terms plus existing replacement-derived hints. A named context resolves only its own explicit terms/aliases; do not merge global hints or another named context into it. Existing final-text replacement rules remain global and unchanged, and the interface explains this distinction.
- R4: Selection is persisted and visible in the contexts settings and the dictation/menu entry and file-transcription surface before starting. Unknown/deleted identifiers resolve to Default. Display the operation's captured context while recording/processing where existing status surfaces permit.
- R5: Capture immutable profile identity, name, revision and effective vocabulary when recording starts, before the first suspension; clear it on finish, cancellation, failure and quick-tap exits. All files in one queue run capture at run start, not window construction or each item. CLI captures its loaded config once. Selection/term edits affect the next operation only. Rename/delete cannot retarget an older result or its displayed captured name.
- R6: Pass the captured vocabulary to the existing Parakeet path for Ultra and v3. Retain acoustic thresholds, serialization and fallback behavior. Default must not create another model cache per context. Whisper retains its existing recognition configuration with an explicit unsupported-context explanation.
- R7: Context content must not implicitly modify language-model provider, model, prompts, conversation history, global replacement rules or learned corrections. No biography field, automatic external context collection or cloud transmission is added. Terms are recognition hints, not guaranteed text replacements.

### Non-functional

- Use existing Codable/AppSettings persistence and native SwiftUI controls/localization. Context selection is keyboard accessible and labelled.
- Do not log vocabulary contents. Existing local model download behavior remains; no new web service.

## Success Criteria

- Legacy decode/round-trip yields disabled Contexts, Default selection and identical global effective vocabulary.
- CRUD/normalization and unknown/deleted selection behavior pass deterministic tests.
- Snapshot tests exercise selection and term mutation after recording/run start and prove unchanged effective vocabulary through completion; next operation observes the update.
- File pool construction does not retain the window's obsolete selection; dictation and file run resolve equivalent configurations identically.
- Existing Nico boundary/non-cascade tests pass, and an injected text processor receives unchanged provider/prompt values after profile changes.
- Assembled native controls expose the selected context and unsupported Whisper state. A public cached-audio Parakeet run exercises the assembled path without claiming recognition superiority.

## Edge Cases

Empty collection disables boosting for that named context; it does not fall back to global names. Deleting an in-flight profile does not erase that operation's snapshot. A failed CTC setup retains the transcript and existing error behavior. Simultaneous file/dictation inference retains existing serialization.

## Out of Scope

Screen, clipboard and contact collection; app/website inference; biography; speech-model training; contextual replacement-rule scoping; LLM context injection; Whisper vocabulary rollout; audio retention; accuracy or speed improvement claims.

## Open Questions

None blocking this bounded slice. Name-level ambiguities remain manual user choices; quality superiority is deferred and not a release claim.

## Related

- Evidence: `doc/research/0017-ground-manual-personalization.md`
- Evaluation: `doc/research/0018-prism-personalization-save.md`
- Task: `doc/tasks/0006-manual-vocabulary-contexts.md`
