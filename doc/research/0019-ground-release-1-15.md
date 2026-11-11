# GROUND-0019: Freeze and distribute Fala1.15 without rewriting1.14

**Status:** recorded
**Decision:** Prepare1.15/build36 and exact factual notes; integrate/review/test the three new feature slices, assemble one signed/notarized candidate, sign final bytes with the existing Sparkle key, and expose only after every actual gate is satisfied or its real remaining process blocker is explicitly resolved.
**Decision ref:** docs/RELEASE.md
**Confidence:** Strong
**Stakes:** medium × reversible

## Decision and confidence

Use the existing phased release path with separate human and machine versions, exact minimum27.2.1, immutable versioned artifacts and verified final-byte signatures (A1,A2,B1,C1,D1). The monolithic release script mutates version/git/tag before assembly and its dry-run still changes local git, so preparation uses existing build/package tools in controlled phases, as the last verified release did (C1,D1). Existing reusable MIT application/source and component notices remain distinct. Exact public notes use the repository's concise release bullet format (C2), English publication plus Portuguese preview and app translations. Private deliberation, personal examples, unsupported accuracy/ROI claims and unfinished follow-ups stay out. Review only new diff since3ba31a7; previous baseline coverage is retained.

## Evidence

### E1 — Human version and monotonic build must agree across app and feed

**Tier:** Primary
**Strength:** Medium
**Provenance:** A1, A2, B1, C1, D1

Apple identifies iterations with CFBundleVersion; Sparkle compares the build and can display the separate short version. The current app record is1.14/build35; the next feature release is1.15/build36. Its minimum is27.2.1 in source, app executable and feed. Do not rewrite the already published1.14 installer/minimum14.0.

### E2 — Sign only final archive bytes and verify both destinations

**Tier:** Measurement
**Strength:** High
**Provenance:** A2, B1, C1, D1

The previous actual1.14 release verified notarization/staple, final-byte Ed25519, versioned/latest download digests and appcast metadata. Reuse that measured sequence, not its claim of readiness for a different binary. Capture1.14 as rollback before replacing latest/feed; immutable1.15 upload first, latest second, feed last, with readback and signature verification. No private key export or replacement. The new candidate has not yet passed those steps.

### E3 — New release claims require new candidate evidence

**Tier:** Primary
**Strength:** Medium
**Provenance:** C2, C3, D1

Five intended factual note claims cover manual Parakeet contexts, explicit approval before global-rule persistence, truthful save failure/recovery, preserved Undo/Edit destination and the minimum OS. Features have focused/independent evidence, but current batch filesystem alias finding, integrated gate, four-language UI, cached real CTC path and final distribution are still pending. Mark each claim evidence as pending until observed. Do not promote planned behavior into completed verification. The machine checker remains Claude-Tool:Skill-only; native Codex records do not make it PASS, and the1.14 host-recognition exception is not transferable.

## Source register

- **A1:** https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleversion.md, numeric bundle iteration/increment contract (accessed 2026-11-10 via official Markdown web read)
- **A2:** https://sparkle-project.org/documentation/publishing/, archive signing, build versus short version and three-part minimum system version (accessed 2026-11-10 via official web read)
- **B1:** https://sparkle-project.org/files/sparkletestcast.xml, actual Sparkle example appcast parsed as XML; item/enclosure/version metadata are the reference implementation pattern, not copied product text (accessed 2026-11-10 via XML fetch and parse)
- **C1:** scripts/release.sh:28,99,128,191,222; docs/RELEASE.md; scripts/build-app.sh; existing1.14distribution/publication receipts. Methods include preserved signing identity, original Mini key and personal R2 config; no credentials are embedded here (accessed 2026-11-10 via source and existing execution receipts)
- **C2:** Sources/FalaCore/Resources/ReleaseNotes.json entries1.14/1.13.1/1.13 and CHANGELOG.md; existing concise factual bullet format, not claimed as personally authored voice examples (accessed 2026-11-10 via repository reads)
- **C3:** Specs0002/0003/0004, tasks0006/0007/0008 and ground0017/PRISM0018; root integration review receipts distinguish new code evidence from pending runtime/UI/claims coverage (accessed 2026-11-10 via repository and receipt reads)
- **D1:** `git log --oneline -- Sources/Fala/Resources/Info.plist Sources/FalaCore/Resources/ReleaseNotes.json CHANGELOG.md`: c4e2d5b prepares1.14; b19615e governs future platform; published signedtagv1.14 identifies fdcc546. Prior publication receipt retains exact unchanged1.14 DMG SHA256c9ca0e6608b78db94fd549ce6eef11b7805869ea94415d60063895527cb1aecc (accessed 2026-11-10 via git/source/receipt reads)

## Limitations and reversal

This is a preparation method and claim ledger, not evidence that1.15 is built/reviewed/notarized/published. Existing code reviews are not repeated; new integration and outward claims get their uncovered checks. No live microphone, installed-app focus, clipboard use, privacy-unknown input, new model download or business-quality benchmark is required or claimed. A real unresolved test, signature, runtime, authority or process-gate failure holds exposure; do not fabricate proof or modify global rules to clear it.

## Audit path

Validate this ground structure, inspect exact code/test/runtime/notes hashes, record all independent findings/dispositions, run the real checker only against final notes and retain its actual result. Finish the concrete candidate before surfacing any last external blocker.

## Native proposal geometry diagnosis

The assembled default controller produced real panel heights of 965pt (pt-BR), 867pt (en), 979pt (es), and 1091pt (fr), despite the declared 400×280pt proposal size. The panels extended below the screen. A real-controller tracer added the pre-existing height contract before changing production; its failures are retained in `.agentic/reviews/release-1.15-native-sizing-red.log`. Callback success alone is insufficient evidence of usable geometry.

- Official API: [NSHostingView.sizingOptions](https://developer.apple.com/documentation/swiftui/nshostingview/sizingoptions) documents that a top-level hosting view updates its window minimum/maximum constraints. An empty option set disables those constraints for an explicitly sized host. Accessed 2026-11-10.
- Implementation reference: [Use SwiftUI with AppKit, WWDC22](https://developer.apple.com/videos/play/wwdc2022/10075/) demonstrates hosting-window sizing ownership and explicit sizing options. This supports letting the existing panel placement own its fixed frame rather than inventing a second layout engine.
- In-repo: `Sources/FalaCore/UI/DictationFeedbackController.swift` wraps its hosting view in an explicitly sized container, separating SwiftUI sizing from window geometry. `InsertionReviewPlacement.proposalSize` already declares 400×280pt; preserve that contract.
- History: commit `c541f8d156977c4450fb7242389d51ae55607a57` adds the proposal as a direct window content host, while `82f9850` preserves destination behavior. The narrow correction changes only the proposal host's sizing ownership and preserves all callbacks and activation behavior.

Decision recorded alongside this implementation: construct the proposal NSHostingView, set `sizingOptions = []`, then attach it to the existing panel. Proceed with mitigation: require four-language real panel height/frame, visible action controls, captured PNG inspection, unchanged frontmost application, protected preferences, and independent delta review. No microphone, real editing target, or clipboard is used. Evidence strength is measured failure plus primary API/reference; confidence in the fix remains conditional until the deciding run.

## Copy recovery evidence gap

The release claims include copying completed text after a batch-save failure. Existing runs observed retention and save-only retry but intentionally did not invoke the general clipboard; they therefore did not empirically establish the copy sink. The source copy action hardcodes `NSPasteboard.general` and has no existing isolated target seam. This is an evidence gap, not an observed product copy failure.

Four-source grounding, 2026-11-10:
- Official [NSPasteboard.withUniqueName](https://developer.apple.com/documentation/appkit/nspasteboard/withuniquename()) provides a uniquely named pasteboard; [releaseGlobally](https://developer.apple.com/documentation/appkit/nspasteboard/releaseglobally()) releases only private boards, never standard boards. Current SDK NSPasteboard.h confirms the cleanup method.
- Implementation reference: [Muse TextInjectionClipboardRestoreTests](https://github.com/DaliangPro/Muse/blob/main/DalTests/TextInjectionClipboardRestoreTests.swift) constructs a private board with withUniqueName and injects it into production clipboard operations. Consulted source SHA256 `08de729d31da98a056abd290c34eaf89b4314c75b73a8967f03c5cc361776396`; API pattern only, no code copied or clipboard lease system adopted.
- In-repo: `Tests/FalaTests/PasteboardSnapshotTests.swift` uses private UUID-named boards and exact string/custom-data readback through the real `PasteboardSnapshot` parameterized operations. Batch save fixtures already exercise the actual TranscriptionJob queue with an isolated failing writer/transcriber and confirmed retained text.
- History: `232442f` introduces the named-pasteboard snapshot tests; `c541f8d` adds the recovery action and bounded batch behavior. Preserve existing UI invocation and default general-board behavior.

Decision recorded alongside this implementation: add one internal destination parameter defaulting to `.general`; the existing UI call remains unchanged. Run the actual failed-save→recoverable queue→copy action with an explicitly passed private board and assert its exact string readback. A second missing-result case must preserve that board's sentinel. Tests never evaluate the default general argument, capture/restore user clipboard contents, issue keystrokes, or use swizzling. The safe first RED is compilation because the controlled destination argument does not yet exist; deliberately invoking the old hardcoded general action is prohibited. This RED does not assert the old copy implementation was broken. Confidence: proceed with mitigation; require executed named sink, focused/full gates, independent narrow review and refreshed signed/notarized bytes before release.
