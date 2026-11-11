# Spec 0001: Evaluate local speaker-labelled file transcripts

**Status:** draft
**Created:** 2026-11-10
**Owner:** Fala maintainer

## Context

Recorded conversations need an accurate account of who spoke when, attached to the actual transcribed words. The published application currently has no active speaker-labelling pipeline. Local work in progress must be evaluated before a new implementation is proposed, so useful work is preserved and competing pipelines are not built independently.

## User Scenarios

- **A recorded conversation:** Given an authorized recording with manually reviewed speaker turns, when the local evaluation runs, then the output contains text, time intervals, speaker labels, and explicit unresolved assignments that can be compared with the reference.
- **An unavailable speaker model:** Given that its model assets cannot be loaded, when optional speaker labelling is requested, then the evaluation records that failure separately from speech recognition; plain transcription remains independently testable.
- **Returning to plain transcription:** Given an evaluated speaker-labelling candidate, when that optional path is disabled, then existing plain-text file transcription remains the control behavior.

## Requirements

### Functional

- Inventory the existing local work before implementing a second timestamp, diarization, or alignment abstraction.
- Compare an offline FluidAudio pipeline first because it shares the current dependency; keep SpeakerKit as a documented alternative rather than updating both SDKs at once.
- Evaluate word/time alignment separately from diarization; a correct speaker timeline alone is not a correct speaker-attributed transcript.
- Record missing/uncertain speaker assignments rather than presenting an inferred label as certain.
- Keep the first scope to prerecorded local files; do not introduce live meeting capture or cross-recording voice identity.

### Non-functional

- Do not upload recordings or reference transcripts to external inference services.
- Keep the application MIT licence distinct from each model/component licence; verify exact distribution terms and asset access before integration.
- Follow the separately governed minimum-OS policy for future builds; the owner-directed baseline is macOS27.2.1 (the current Mac's version), with `doc/adr/0002-macos-support-baseline.md` being prepared by the platform delivery. Report candidate incompatibility explicitly. This supersedes the earlier macOS14 requirement; it does not imply that macOS14 runtime was tested or change published1.14 artifacts.

## Success Criteria

- The work-in-progress assessment identifies reusable components, tests, and missing evidence without modifying or discarding the original work.
- A reproducible evaluation records diarization error, speaker-attributed word errors, processing time, peak memory, and unassigned segments for each chosen public or authorized fixture.
- Fixtures include silence, speaker changes, overlapping speech, and a speaker count beyond any candidate's advertised fixed limit.
- The result is an evidence-based recommendation or rejection with exact model/SDK identities; production quality thresholds and UI are approved before implementation.

## Edge Cases

- No speech, one speaker, short turns, crosstalk, quiet/distant speech, unknown speakers, and long files.
- Model access restrictions, failed downloads, memory pressure, cancellation, and timestamps that do not cover a transcript word.

## Out of Scope

Production rollout, a default-on speaker feature, speaker enrolment or biometrics across recordings, live audio capture, cloud processing, automatic model purchase, and an unmeasured claim of accuracy.

## Open Questions

- Which labelled public or authorized Portuguese fixtures represent the intended users? Resolve before the evaluation is frozen.
- What quality, memory, and waiting-time tradeoffs are acceptable for production? Define before a deciding run, not from the winning result.
- Should the first output be a readable transcript, subtitle file, or editable timeline? This is a later product decision; the evaluation retains structured intervals without prescribing the shipped UI.

## Related

- ADRs: `doc/adr/0001-free-open-source.md`
- Tasks: `doc/tasks/0004-evaluate-speaker-labelled-files.md`
- Depends on: selected-model integration in `doc/tasks/0001-selectable-parakeet-ultra.md`

## Current platform-policy integration

ADR0002 is accepted and integrated for subsequent source builds at macOS27.2.1; the earlier note that it was being prepared is superseded. This policy does not implement speaker-labelled files, change this spec’s success criteria, validate real microphone/focus behavior or alter the published1.14 installer.
