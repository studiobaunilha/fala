# GROUND-0014: Export test audio with the supported async API

**Status:** recorded
**Decision:** Await AVAssetExportSession.export(to:as:) in M4A fixture helpers and their test callers.
**Decision ref:** doc/adr/0002-macos-support-baseline.md
**Confidence:** Strong
**Stakes:** low × reversible

## Decision and confidence

Use `try await session.export(to: outputURL, as: .m4a)` and async throwing helpers, following Apple's documented API and actual SDK implementation (A1,B1). Remove manual output-property configuration, completion/semaphore blocking and deprecated status/error polling. Existing tests already use async throws for asynchronous work (C1). Retain the shared PCM producer and a synchronous WAV wrapper; only helpers that may export M4A and their callers need async. Remove the unused XCTestCase parameter from the export helper rather than pass a non-Sendable test object across suspension. Historical fixture intent is Apple-produced AAC for converter/batch validation (D1), not capture or production audio changes.

## Evidence

### E1 — The SDK provides async export with native cancellation and error propagation

**Tier:** Primary
**Strength:** Medium
**Provenance:** A1, B1

Apple documents output location, file type, inherited isolation, async throws and Task cancellation. The SDK overlay implements the method with `try await withTaskCancellationHandler`, configures output internally and interprets completion/error states. The helper should await that API rather than reproduce it behind a blocking semaphore.

### E2 — The failure is confined to fixture export and async caller propagation

**Tier:** Measurement
**Strength:** High
**Provenance:** C1, D1

The combined gate compiled the updated production AudioEngine, then reported six deprecation errors in AudioTestFixtures.swift79–93. The helper is used by converter, batch preparation and prepare-only CLI tests. A similarly named helper in TranscriptionJobTestSupport has different arguments and uses native AVAudioFile; it is outside this delta. The waveform generation and production converter are unchanged.

## Plan and evaluation before edits

1. Compile the actual fixture source using explicit Xcode27.2, Swift6, deployment27.2.1 and warnings-as-errors; observe the existing deprecated export failure.
2. Migrate helper and necessary callers with direct awaits. Preserve synchronous WAV callers by calling the existing PCM producer directly. Delete the now-unused exportIncomplete status wrapper.
3. Require fixture compilation GREEN and actual exported mono/stereo M4A metadata/duration/AAC checks. Then compile/test the relevant package test callers, expanding to the canonical full package gate if practical to reveal remaining SDK blockers. Serial heavy execution only; no release build or installed-app change. Review only this fixture/caller delta and the authorized0013link correction, preserving already-reviewed production audio/floor bytes.

## Source register

- **A1:** https://developer.apple.com/documentation/avfoundation/avassetexportsession/export(to:as:isolation:).md — supported async throwing export and cancellation (accessed 2026-11-10 via webopen).
- **B1:** Xcode27.2 build27B52/macOSSDK27.2, usr/lib/swift/AVFoundation.swiftmodule/arm64e-apple-macos.swiftinterface:1369–1412 — actual implementation of async export, native cancellation handler and completion/error mapping; AVFoundation.framework/Versions/A/Headers/AVAssetExportSession.h:254–275 deprecates old status/error/export API. Reproduce with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun --sdk macosx --show-sdk-path` and read these public SDK paths (accessed 2026-11-10 via localSDKread).
- **C1:** Tests/FalaTests/AudioTestFixtures.swift:9,47,70; AudioConverterTests.swift:61,77,99,114; BatchAudioPreparerTests.swift:6; BatchCLIIntegrationTests.swift:31; DictationModeTests.swift:73 uses async throws for async tests (accessed 2026-11-10 via localread).
- **D1:** 45e045bd79955a8798757499cadff7c16ba4cff5, Tests/FalaTests/AudioTestFixtures.swift — introduced Apple-generated AAC fixtures to validate native AAC paths; `git log --all -- Tests/FalaTests/AudioTestFixtures.swift` found no previous async-export migration (accessed 2026-11-10 via gitshow).

## Limitations and reversal

These are generated test files, not microphone capture or public data. The existing runtime tap smoke remains separate. No change to floor, production AudioEngine, insertion controller, app version, public1.14 or permissions. The sole0013correction is the diagnosis receipt filename; its failed-mixer history remains intact.

## Audit path

Validate this record before code; retain RED/GREEN/export metadata and SDK source snippets in .agentic/reviews. Review only changed fixture/caller lines once.

## Observed evaluation

RED: actual AudioTestFixtures.swift compilation reported all six deprecated export uses under Swift6/warnings-as-errors and target27.2.1. GREEN: the same helper typechecked, and the standalone runtime produced actual AAC M4A for mono and stereo at48000Hz, each measured duration0.5seconds. The shared async M4A route and existing synchronous WAV route also passed, with WAV4000frames at16kHz/mono. SDK/XCTest linkage in the standalone runner follows the repository's existing Package.swift test-framework paths and explicitly clears an inherited SDKROOT before resolving the Xcode SDK; no source API shim is used.

All68 Swift test-source files in the platform worktree typechecked together against the integrator's already compiled FalaCore module, under the same Swift6/warnings-as-errors/27.2.1 floor. This exercised all updated test callers and exposed no remaining SDK deprecation in that scope. It is a direct typecheck, not a canonical full-package build or execution of converter/CLI tests; the combined gate still belongs to the integrator. Focused strict lint passed for the five changed/new Swift files. Production AudioEngine remains byte-identical to the reviewed B96 target; floor configuration is unchanged. No microphone, app, public release or permission change occurred.

Receipts: `.agentic/reviews/audio-export-red.log`, `audio-export-green.log`, `audio-export-all-tests-typecheck.log` and `audio-export-sdk-official-fragment.txt`. The0013addendum corrects only the receipt filename from audio-tap-runtime-diagnosis.md to audio-runtime-diagnosis.md; the earlier failed-mixer observations remain recorded.

## Integration closure

Independent review of eight-file delta f3cbfbf7a17eabb6f2fdb80a344cefc2797c8a78183e8e5154f5556ece158110 plus README delta df52b7314d26ae65cc08db5a801ba5c01f8a1e897a437c543403acb9aa3dd639 reports Standards0/Spec0; actual helpers, mono/stereo AAC, WAVsync and error propagation inspected. Later integrated canonical gate executed324cases/2optional skipped/0failures; prior68-file typecheck was compilation only and is not mislabeled as test execution.

Review provenance: summaries forwarded by the orchestrator from independent fresh-context reviewers; execution receipts are under `.agentic/reviews/priority-*`. This addendum records local integration evidence, not an additional source review or release.
