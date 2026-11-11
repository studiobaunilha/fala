# GROUND-0013: Use the supported macOS 27 audio tap

**Status:** recorded
**Decision:** Replace the deprecated tap with installAudioTap and consume its read-only PCM buffer directly.
**Decision ref:** doc/adr/0002-macos-support-baseline.md
**Confidence:** Strong
**Stakes:** medium × reversible

## Decision and confidence

The new27.2.1 floor exposes a real AVFAudio deprecation under the existing warnings-as-errors gate. Use the canonical Swift installAudioTap API and its @Sendable read-only callback (A1,A2,B1). AVAudioFile has an overload accepting that buffer directly; RMS can read its float channel span without making a mutable copy. Preserve bus0, requested4096frames, format, capture list, writer/handler locks, engine prepare/start/stop and tap removal (C1,D1). Propagate installation errors through the existing throwing startRecording API. Do not lower warnings or route through underscored Objective-C refinements. This is platform maintenance, separate from insertion-controller product gains.

## Evidence

### E1 — The replacement is throwing and changes the buffer type

**Tier:** Primary
**Strength:** Medium
**Provenance:** A1, A2, B1

Apple's Swift API uses installAudioTap with a sendable callback receiving AVReadOnlyAudioPCMBuffer. Xcode27.2 SDK header AVAudioNode.h117 marks the old method deprecated27.0;160 declares the error-returning replacement. The Swift overlay exposes installAudioTap at247 and direct file writing at332. Its read-only buffer provides channelData at45. The header's new-method example installs the tap with an NSError result and receives PCM; the Swift overlay provides the supported safe callback representation. No callback copy is necessary in project code.

### E2 — The application already has a throwing lifecycle and separate handler lock

**Tier:** Measurement
**Strength:** High
**Provenance:** C1, D1

AudioEngine.startRecording throws, and AudioWriter protects file ownership with its own lock. The callback intentionally avoids MainActor and acquires a separate handlerLock. Commitcab795d fixed a lock inversion; preserving those locks is a load-bearing constraint. The callback calculation consumes the first float channel and leaves non-float audio without an RMS update.

### E3 — Offline manual rendering can test the new callback shape without capture

**Tier:** Primary
**Strength:** Medium
**Provenance:** A3, B1

AVAudioEngine manual rendering is driven by the caller rather than an audio device. Use an AVAudioSourceNode with fixed0.25float PCM, a mixer tap, direct read-only WAV writing and RMS checks. This exercises the new API, not inputNode/microphone permissions. The application source itself must also compile under Swift6 and warnings-as-errors. This smoke does not prove hardware capture or an assembled Fala release.

## Diagnosis and frozen evaluation

The integration gate failed at AudioEngine.swift59 with deprecated installTap. Proportional diagnosis: H1, the raised floor exposes an obsolete API; replacing it with the documented API should clear the error. H2, stale/wrong SDK might cause a misleading diagnostic; compile the actual source with explicit Xcode27.2 to distinguish it. H3, a rename alone might not preserve writer/RMS typing; the official read-only overload and channel span must compile and preserve golden PCM/RMS. H1 is strongly supported by the SDK declaration before any edit; no capture experiment is needed.

Plan before code: add a script that typechecks actual AudioEngine.swift, AudioRecording.swift and Errors.swift with explicit SDK27.2/Swift6, deployment27.2.1 and warnings-as-errors. Supply only a temporary localization identity shim; no audio code is stubbed. Observe RED for the known deprecated call. Implement the minimal supported adaptation. Require the same check GREEN plus a separately compiled/started offline engine rendering fixed PCM through the new tap, direct WAV roundtrip and expected RMS0.25. Stop on unexpected format/concurrency/API failures. No microphone, inputNode, actual device capture, permission change, app restart or network is allowed. Integration owner runs fullpackage/app gate after review.

## Source register

- **A1:** https://developer.apple.com/documentation/avfaudio/avaudionode/installaudiotap(onbus:buffersize:format:tapprovider:).md — canonical throwing sendable read-only tap (accessed 2026-11-10 via webopen).
- **A2:** https://developer.apple.com/documentation/avfaudio/avaudiofile.md and https://developer.apple.com/documentation/avfaudio/avreadonlyaudiopcmbuffer.md — read-only write overload and channelData (accessed 2026-11-10 via webopen).
- **A3:** https://developer.apple.com/documentation/avfaudio/avaudioengine/enablemanualrenderingmode(_:format:maximumframecount:).md — manual rendering uses caller-provided source data (accessed 2026-11-10 via webopen).
- **B1:** Xcode27.2 build27B52, macOS SDK27.2: AVFAudio.framework/Versions/A/Headers/AVAudioNode.h147–160 provides the new tap example; Modules/AVFAudio.swiftmodule/arm64e-apple-macos.swiftinterface245–247 and328–333 expose the actual Swift declarations. Reproduce via `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun --sdk macosx --show-sdk-path` then read the corresponding public SDK framework paths (accessed 2026-11-10 via localSDKread).
- **C1:** Sources/FalaCore/Core/AudioEngine.swift:5,46,59,86; Sources/FalaCore/Protocols/AudioRecording.swift:5 — writer, throwing lifecycle, tap and stop protocol; no second tap implementation found by `rg installTap Sources Tests` (accessed 2026-11-10 via localread).
- **D1:** cab795ddcb099cbe2f8b409347acace1a7e69579, Sources/FalaCore/Core/AudioEngine.swift — separate handlerLock prevents stop/callback inversion; `git log --all -- Sources/FalaCore/Core/AudioEngine.swift` found no previous SDK27tap migration (accessed 2026-11-10 via gitshow).

## Limitations and reversal

Offline rendering checks API/dataflow only. Physical microphone capture and realtime cadence remain untested in this change; the user is using the unchanged published1.14 app. No unsupported-OS claim or performance improvement is inferred. Writer error reporting remains unchanged. New installation errors and engine-start errors now close the writer, remove the temporary file, remove an installed tap and clear the pending URL before rethrowing. Hardware startup/failure recovery itself remains unexecuted because it would require microphone/device access; no new capture injection abstraction was introduced.

## Audit path

Validate this receipt and review only AudioEngine/newsmoke delta after GREEN; preserve prior platform/insertion review coverage.

## Observed diagnosis and evaluation

The real AudioEngine source reproduced the exact SDK27 deprecated-call failure under explicit Xcode27.2, Swift6, target27.2.1 and warnings-as-errors. After the supported migration it typechecked without warning suppression. The first offline fixture trapped during direct read-only file writing, before RMS access. A bounded LLDB probe exposed AVAudioBuffer.mm284: two physical buffers versus a declared one-channel format on the offline mixer tap. File isOpen was true, ruling out a simple closed-file race. A newly owned readonly buffer written synchronously outside an engine passed. Changing only the mixer fixture from mono to stereo passed; separately changing only the tap target from mixer to the source node also passed in mono. The trap was therefore a fixture tap-format mismatch, not evidence to work around the supported production API.

The final fixture taps the source node with its actual connection format, independently for one and two channels. Both rendered65536frames, wrote/read the WAV samples unchanged at0.25, and measured RMS0.25 using the read-only channel span. Callback spans remain scoped; only scalar state escapes under a lock. The file is cleared under that lock before teardown can accept a late callback. No inputNode, microphone or capture device is accessed by the runtime fixture. The actual production class, protocol and error declarations are separately compiled; the only shim is localization text lookup. These observations do not claim a hardware recording test or a full Fala bundle validation.

The cleanup defer covers installation and engine-start throws while leaving successful start/stop/callback locks unchanged. Existing writer write-error swallowing remains unchanged. Focused strict lint passed for both Swift files; no debug probes remain in production or the retained fixture. The integration owner still must run the canonical full gate and assembled-app check.

Retained local evidence: `.agentic/reviews/audio-tap-red.log`, `audio-tap-green-final.log`, `audio-tap-lldb.log`, `audio-runtime-diagnosis.md`, and `audio-sdk-official-fragments.txt`. Temporary diagnostic controls are isolated under ignored `.build/audio-sdk-probes`; none is linked into the application.

## Integration closure

Independent review of patch b96e3dd33cc39b6ce14b01bd182bfacb263385ec650aa8e8aac067f0b61a9c1a reports Standards0/Spec0 after inspecting primary SDK declarations and offline real-tap evidence. Integrated package gate324cases/2skipped/0failures and assembled app now pass. This is not live microphone/device start/failure cleanup evidence.

Review provenance: summaries forwarded by the orchestrator from independent fresh-context reviewers; execution receipts are under `.agentic/reviews/priority-*`. This addendum records local integration evidence, not an additional source review or release.
