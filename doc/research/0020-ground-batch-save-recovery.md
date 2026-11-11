# GROUND-0020: Recover completed batch text after saving fails

**Status:** recorded
**Decision:** Propagate streaming file errors through the existing queue, retain the completed processed text in memory, and retry saving that exact text without repeating recognition or post-processing.
**Decision ref:** doc/specs/0004-truthful-batch-save-failures.md; doc/tasks/0008-truthful-batch-save-failures.md
**Confidence:** Strong
**Stakes:** medium × reversible

## Decision and confidence

A transcript can be valuable even when its destination stops accepting writes. The existing queue must distinguish recognition from successful file output. Reuse Foundation's throwing file operations and atomic String write (A1/A2), the application's processing result and retryable queue state (C1/C2), and the separation of completed text from export outcomes shown by Vibe (B1). Continue collecting processed windows after an append error, retain their complete text on the failed queue item, and let the existing retry action save it atomically at the currently selected destination. Copy provides immediate recovery. No new queue, persistence layer or model is needed. Existing incremental output and completed-item handling remain the canonical paths (D1).

## Evidence

### E1 — Save failures currently have no queue signal

**Tier:** Primary
**Strength:** Medium
**Provenance:** A1, A2, C1, C2, D1

`appendToFile` uses optional file opening/closing and a nonthrowing write. Its caller returns a successful processed outcome regardless of whether a file was opened. `BatchProcessingResult` already carries all confirmed processed text, but execution reads only its warning before the queue records `.done`. The static mechanism needs a regression through `transcribe()` with a real destination removed after initialization. This record does not itself claim that test passed or a production incident occurred.

### E2 — Recover existing text rather than invoke recognition again

**Tier:** Primary
**Strength:** Medium
**Provenance:** B1, C1, C2, C3

Vibe retains transcript segments separately from its export result, and its `exportFinished` retries exporting existing segments. Its specific success vocabulary differs from Fala's file-centric `.done(URL)` and is not copied. Fala already owns a completed processed string and retryable per-item errors, so in-memory recovery can reuse those seams. Atomic save must complete before Fala marks that item done. Retaining only complete processed results avoids presenting interrupted partial recognition as a completed transcript. No code is transplanted from the GPL reference.

### E3 — Bounded evaluation and compatibility contract

**Tier:** Opinion
**Strength:** design choice
**Provenance:** C1, C2, C3

Before implementation, freeze these outcomes: a real append failure never becomes done; completed text remains recoverable; retry after choosing a usable destination writes the exact retained text with no recognition or LLM call; repeat failure retains recovery; ordinary multi-file output, basename disambiguation and cancellation stay covered by existing tests. Text lives only for the queue lifetime. Clearing/removing an item intentionally discards its recovery. Runtime focus, speech accuracy and persistence across application restarts are outside this check.

### E4 — Reservation must compare filesystem identity, not URL spelling

**Tier:** Primary
**Strength:** Medium
**Provenance:** A3, A4, B2, C4, D2

The independent review found a concrete data-loss path: a completed `Meeting.txt` and retry candidate `meeting.txt` can be the same APFS file while their standardized URL values differ. Directory symlinks create a similar alias. Apple documents fileResourceIdentifier specifically for filesystem equality, including paths linked to the same inode on the same filesystem; its NSObjectProtocol isEqual is the canonical comparison. Resolve directory symlinks, preserve normalized URL reservations for not-yet-created paths, and compare fresh file resource identifiers for existing candidates. Do not lowercase paths: that would conflate distinct files on a case-sensitive volume. Clear cached URL resource values because atomic writes may replace file inodes. If an existing candidate or reserved file cannot supply identity, conservatively reserve the existing candidate rather than assume it is unrelated. No persistent identifiers or custom inode implementation are needed. A new public-queue RED must demonstrate actual first-output bytes overwritten through the case alias before this correction.

## Source register

- **A1:** [Apple Foundation String write](https://developer.apple.com/documentation/foundation/nsstring/write(to:atomically:encoding:).md), declaration and atomic auxiliary-file replacement semantics, Foundation SDK27.2. (accessed 2026-11-10 via web/HTTPS)
- **A2:** [Apple FileHandle seekToEnd](https://developer.apple.com/documentation/foundation/filehandle/seektoend().md), throwing file operation. The installed SDK `Foundation.framework/Headers/NSFileHandle.h:72–123,345–352` supplies error-returning writes/close and documents the Swift throwing names. (accessed 2026-11-10 via web/HTTPS and installed SDK read)
- **B1:** [Vibe pinned queue](https://github.com/thewh1teagle/vibe/blob/da8c2ca53b6c7ff44f7a1314c3be862d466c3427/desktop/src/pages/main/hooks/use-transcribe-queue.ts#L525-L541), fetched raw source: `const pending = jobsRef.current.filter((job) => job.status === 'done' && job.segments.length > 0 && !job.exported)`; the callback exports each existing job. Lines277–301 separate export outcome from text. Behavioral reference only; no GPL source copied. (accessed 2026-11-10 via web/HTTPS)
- **C1:** `Sources/FalaCore/UI/TranscriptionJob+Processing.swift:176–195,228–342`, incremental append and processed-text accumulator; `TranscriptionJob+LLMProcessing.swift:8–11`, completed result. (accessed 2026-11-10 via local read)
- **C2:** `Sources/FalaCore/UI/TranscriptionJob+Execution.swift:66–109`, result consumption; `TranscriptionJob+Queue.swift:219–327`, existing terminal success/failure; `TranscriptionJob.swift:131–161`, retryable-item execution. (accessed 2026-11-10 via local read)
- **C3:** `Tests/FalaTests/IncrementalSavingTests.swift:12–76` and `TranscriptionJobTests.swift:102–194`, real output assertions and basename disambiguation; `TranscriptionJobTestSupport.swift:76–119`, existing no-model transcriber seam. (accessed 2026-11-10 via local read)
- **D1:** `git log --oneline -8 HEAD -- Sources/FalaCore/UI/TranscriptionJob+Processing.swift Sources/FalaCore/UI/TranscriptionJob+Queue.swift Sources/FalaCore/UI/TranscriptionJob+Execution.swift` finds `e385ffe` final-text corrections, `7d7a426` file-saving timing, and `84ee781` batch queue UI. `git worktree list` identifies concurrent isolated feature delivery; original personal checkout is untouched. (accessed 2026-11-10 via local Git)

- **A3:** [Apple fileResourceIdentifierKey](https://developer.apple.com/documentation/foundation/urlresourcekey/fileresourceidentifierkey), [fileResourceIdentifier](https://developer.apple.com/documentation/foundation/urlresourcevalues/fileresourceidentifier.md): isEqual compares actual filesystem objects, including same inode/filesystem. (accessed 2026-11-10 via web/HTTPS)
- **A4:** [Apple resolvingSymlinksInPath](https://developer.apple.com/documentation/foundation/url/resolvingsymlinksinpath().md) and [removeAllCachedResourceValues](https://developer.apple.com/documentation/foundation/url/removeallcachedresourcevalues().md): symlink resolution and current resource metadata. Installed SDK27.2 Foundation.swiftinterface:12901,13423 confirms actual signatures. (accessed 2026-11-10 via web/HTTPS and SDK read)
- **B2:** [Swift Foundation URL implementation](https://github.com/swiftlang/swift-foundation/blob/main/Sources/FoundationEssentials/URL/URL.swift#L207-L214), fetched raw source shows the typed fileResourceIdentifier getter delegates to `_get(.fileResourceIdentifierKey)` and documents isEqual as its equality contract. Reference API implementation only, no source transplanted. (accessed 2026-11-10 via web/HTTPS)
- **C4:** `Sources/FalaCore/UI/TranscriptionJob+Queue.swift:198–213,235–238` in frozen tree31f4932 uses standardized URL set membership for reservation; `TranscriptionJob+Output.swift` atomically overwrites the retry destination. No file-identity analog found by `rg -n 'fileResourceIdentifier|resolvingSymlinksInPath|volumeIdentifier' Sources Tests`. (accessed 2026-11-10 via local read)
- **D2:** `git log --all --oneline -3 -S fileResourceIdentifier -- Sources Tests` returned no prior attempt; existing reservation came from the queue implementation and this bounded retry patch. (accessed 2026-11-10 via local Git)

## Limitations and reversal

This is a documented implementation path, not a measured speed or quality claim. Queue state remains session-local. A failure before recognition starts has no completed text to retain and remains an ordinary retry. If real queue testing disproves the error mechanism, stop rather than add a speculative recovery architecture. A completed retained result is immutable for retries; later mode or vocabulary changes do not silently reprocess it.

## Audit path

Run `node /Users/ale/.agents/skills/ad-ground/scripts/validate-record.mjs doc/research/0020-ground-batch-save-recovery.md`, then reopen cited source sections. Regression evidence and a fresh-context review must cover the final implementation separately.

## Assessment

Worker reproduction confirmed the ignored append-open error through the real public queue boundary. A second regression reproduced destructive same-basename reuse on retry. Nine new behavior cases and23 existing controls passed in the final focused32-test run, with strict lint13/0. Failed initial output, failed streaming append, failed retry overwrite, complete retention, save-only retry, independent mixed queue items, existing output preservation, current TXT/MD serialization, no replacement replay, unavailable-model readiness/warm bypass, cancellation after partial failed append, and one successful LLM request without retry repetition are covered. This is a deterministic native queue/filesystem evaluation using existing fake ASR adapters, not measured speech accuracy, physical GUI/clipboard use or a full integrated release gate. Foundation seek/write/close are throwing in source; individual kernel-level seek/write/close fault injection was not performed. `SegmentProcessor` has no call sites in the searched source and is not part of this queue path.
