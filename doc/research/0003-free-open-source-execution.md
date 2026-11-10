# Free and open-source execution record

Status: local implementation completed; release gates remain open. No public availability claim.

## Revisions and isolation

- Application built from `ecd6fdb1f24e4c88089099a2046c5c497e6c7439`, based on `bc10862`; branch `codex/free-open-source` in the isolated app checkout. Subsequent signing-preflight and record changes do not change the app sources or this binary.
- Website: `d6d90fe9ae6d3094513b77369c53b1ce9096fc68`, based on `4ac5e2f`; separate personal checkout and branch.
- The original application's unrelated uncommitted changes were preserved. Neither repository was pushed or made public. No production database or payment records were changed.
- The accepted distribution decision is `doc/adr/0001-free-open-source.md`. The frozen evaluation remains `doc/research/0002-prism-free-open-source-release.md`, SHA-256 `f239b31c4edcef626cf196f053390186d10286f37cd5768d946364fe594e2018`.

## Observed checks

| Check | Observation | Code state / reproducible path |
|---|---|---|
| App tests and lint | 285 XCTest cases, zero failures; strict SwiftLint zero violations in 183 files | Pre-commit gate for ecd6fdb; `make test` and `make lint`. Local log `/tmp/fala-oss-release-fix-commit.log` |
| Website tests | Six Worker tests, zero failures; TypeScript and ESLint passed | Website SHA above; package test/lint and `tsc --noEmit` |
| Website build | 65 pages built | Website SHA above; Astro build |
| Assembled website | 96 checks passed across 13 locales, free download/source links, legacy checkout routes and retired endpoints | Build first, start local Wrangler, run `node scripts/verify-local-site.mjs`; restart local Wrangler after rebuilding assets |
| Release bundle | Signature verified with `codesign --verify --deep --strict`; localization verifier passed; version 1.13 / build 33; no commercial plist keys | `bash scripts/build-app.sh release --app-dir "$PWD/.build/release-artifacts/Fala.app"`; log `/tmp/fala-oss-committed-candidate-build.log` |
| Third-party notices | Bundled bytes equal source; seven previously missing embedded notices/licenses present verbatim | `Sources/FalaCore/Resources/ThirdPartyNotices.txt`; pinned SourcePackages checkout |
| Offline transcription | Signed packaged executable produced usable output containing “country” with all process network access denied | Parakeet, existing downloaded model, public JFK fixture below; log `/tmp/fala-oss-final-offline.log` |
| Secret-pattern scan | 292 commits scanned, no findings | Gitleaks 8.30.1 `git --redact`, through ecd6fdb; `/tmp/fala-oss-release-history-scan.log` and JSON. Later local script/record changes need final scan before exposure |
| Native launch | LaunchServices and direct `--help` exited 0 | Does not validate microphone, selected-text commands or first-run interaction |

The suite's trailing empty Swift Testing run is not counted as evidence; the 285 count is XCTest. The offline CLI's generic “Model: large-v3-turbo” label does not identify the running engine: the configured engine was Parakeet. No speed or comparative-quality claim is made.

Fixture: `https://raw.githubusercontent.com/ggml-org/whisper.cpp/master/samples/jfk.wav`, 352078 bytes, SHA-256 `59dfb9a4acb36fe2a2affc14bacbee2920ff435cb13cc314a08c13f66ba7860e`. Local network-denied invocation: `sandbox-exec -p '(version 1)(allow default)(deny network*)' .build/release-artifacts/Fala.app/Contents/MacOS/Fala transcribe "$PWD/.build/verification/jfk-offline.wav" --profile`.

## Exact installer candidate

- Version: 1.13, build 33.
- Local artifact: `.build/release-artifacts/Fala-1.13.dmg`.
- Size: 18292635 bytes.
- SHA-256 after stapling: `13d85e58474191a2588001937c2bdd549c395ec259602392619f079353daa2f3`.
- Apple notarization: Accepted, submission `ff30edff-15cc-4bf9-8c3b-210b6da2c0e8`. Staple and ticket validation passed. Earlier accepted package is superseded and is not evidence for these bytes.
- Sparkle: originally blocked because the key was absent from this Mac. Resolved on 2026-11-10: the exact stapled DMG was signed on the original signing Mac; independent local Ed25519 verification succeeded against the unchanged `SUPublicEDKey` in the application. The key stayed in its original Keychain; no private key was exported, copied or rotated. A local appcast candidate was generated and has not been uploaded.
- Developer ID signing and Apple notarization do not replace the missing Sparkle update signature.

The source notice resource, signed app and staged app were compared before generating this DMG. A subsequent binary/resource change invalidates this package receipt and requires repackaging.

## Audit findings and dispositions

The scoped same-session distribution audit targeted bfcf62f; this is not an independent runtime or website review. Local trail: `.agentic/reviews/2026-11-09-audit-distribution.md` and paired verdicts. Durable dispositions:

- F1, major: omitted SwiftCrypto/SwiftASN1 NOTICE and embedded MLX component licenses. Fixed by `568fbae`; all seven complete source texts were compared against the bundled resource and final bytes matched.
- F2, major: release push targeted unrelated local main and swallowed failure. Fixed by `ecd6fdb`; disposable repository experiment observed old command leaving remote main unchanged and corrected explicit HEAD/tag refspec publishing intended main. Both shell scripts pass syntax checks.
- F3, minor: local notarization helper used an unavailable profile. Fixed by `ecd6fdb`; personal profile was validated. Full helper was not run because it installs into the user's Applications directory.
- F4, minor: the explicit pre-implementation rule-source diff execution was not separately retained. Accepted as an evidence-timing limit; repeat fetch/rule-source comparison before any push and do not assert an earlier retained command.
- F5, major: existing release preflight ran `generate_keys`, which could create a replacement if the original key was absent. A disposable stubbed release invocation reproduced the generator call. The corrected preflight signs only a temporary probe using the existing key and exits with a recovery instruction when unavailable. Green probe exited 1 without invoking the generator; shell syntax passed. No real signing key was created during the reproduction. Evidence: `/tmp/fala-signing-preflight-proof.json`.

Apple's onboarding guidance was read from `https://developer.apple.com/design/human-interface-guidelines/onboarding.md`; this closes the earlier source-access limitation, not the full interactive UI gate. FluidAudioTTS/ESpeak is a separate product and is not selected by Fala's core FluidAudio dependency. This is a scoped dependency observation, not a legal clearance of every third-party term.

## Open release gates

1. Resolved code-review portion on 2026-11-10: three fresh-context reviewers completed four bounded Standards/Spec slices with zero findings. Critical claims hardening and final exposure-content review remain separate audit gates.
2. Resolved on 2026-11-10: remote signing with the original key and independent local verification succeeded. Preserve the exact package and signature; a changed package requires a new signature.
3. Real packaged first-run, hardware dictation and selected-text commands; update from an installation with absent/expired commercial state in an isolated environment. Window/unit tests and offline CLI do not retire these scenarios.
4. Authenticate personal Cloudflare in an isolated configuration and verify the intended account; inspect the live Paddle catalog and pending events before stopping sales/removing runtime. Current public checkout configuration is live. Removing local site buttons is not provider closure.
5. Complete content/exposure review and final exact-set scan, then present the concrete publication packet and receive final exposure authorization. Preserve the private studio-site repository.
6. After publication: anonymous source/tag access, exact public download hash, live site/legacy routes, update feed and actual no-new-sales state. No deployed result is asserted yet.

A release executable launched from a read-only working directory prints an LLVM profile-file diagnostic while `--help` exits 0. A trial coverage flag did not retire it and was removed; no ineffective workaround was shipped. Its provenance was not established. This observation is retained separately from licensing behavior.

Local logs and ignored review packets are working evidence, not permanent public attachments. This tracked record preserves the observations, identities and limitations needed to reproduce or reassess them.

## Update-signing verification — 2026-11-10

The original signing host accepted the configured personal SSH identity after local authorization. The transferred DMG matched the SHA-256 recorded above. SSH-session signing was denied by the macOS Keychain; invoking the existing signing tool from native Terminal on that host succeeded (exit 0). Only the public signature was retrieved. Local verification used Python cryptography Ed25519PublicKey and the existing application public key; verification succeeded on all 18292635 bytes. No private key bytes were displayed or transferred.

Public signature: `Zd7XYLBwf+UTNCDOUXzYAthuy9D9VB65QHzTr0qPYI0CBz8vnKLnIYLnzEpTQUGelkspu+bQDPK+KpOkf6BYAQ==`. Installer SHA-256 remains `13d85e58474191a2588001937c2bdd549c395ec259602392619f079353daa2f3`. The appcast candidate's enclosure length, version 1.13/build 33 and signature refer to these same bytes. Native Terminal signing on the original host is now an observed distribution path; the local release script still requires a locally available key, so it was not run as a substitute. This resolves update-signature authenticity, not the still-unexecuted old-client update scenario or public delivery checks.

## Independent code review — 2026-11-10

Three fresh-context reviewers received only bounded diff, applicable standards and specification/evidence packets. App target: `cf0ce7ac98270b0b83856314f54ef8b518a6c964`; website target: `d6d90fe9ae6d3094513b77369c53b1ce9096fc68`. Four slices were each below 50 files: application runtime/tests (46), distribution/resources/docs/scripts (21), website server (19) and website pages/scripts/localizations/legal (37). Commit-count integrity checks passed (six app commits, one website commit). Review roles were read-only and the reviewer-reported git status was clean before and after. No build/test gate was repeated by a reviewer.

Each slice reported, verbatim, **“no real issues found in this axis”** on both Standards and Spec axes: zero Blockers, zero Concerns, no surviving findings to fix. The orchestrator persisted the returned verdict text immediately because reviewer roles prohibit writes. Paired local receipts: `.agentic/reviews/2026-11-10-review-app-runtime-verdicts.md`, `...app-distribution-verdicts.md`, and the website checkout's `...site-server-verdicts.md` / `...site-pages-verdicts.md`. No reviewer emitted overall approval or a claim of publication readiness.

The reviewers explicitly retained the packaged first-run, real dictation/selection, absent/expired-client migration, provider-closure and public-delivery gates. The configured binary minimum macOS was independently read as 14.0 with `xcrun vtool -show-build`; this does not assert empirical compatibility on every macOS 14 system.

Personal Cloudflare access was also confirmed read-only for worker `studiobaunilha` and release bucket `fala-updates`, using a configuration separate from the work account. Current deployed worker version read back as `c9f053ec-fd3a-4641-a5f7-b1c7267804a9`. No upload, deploy, visibility change or commercial data operation occurred.

## Provider readback and second-Mac validation — 2026-11-10

Authenticated read-only access to the live Paddle catalog and relevant transaction, subscription and webhook views was completed. The configured public checkout price matches the catalog price. No price, transaction, customer record or notification setting was modified. Commercial shutdown remains a separate unexecuted operation; private merchant readback details are retained only in an ignored local receipt, not this public-source record. The webhook log observation is limited to the UI view shown, not a global lifetime delivery-clearance claim.

The exact stapled/signed DMG was transferred to a second Mac and its SHA-256 matched `13d85e58474191a2588001937c2bdd549c395ec259602392619f079353daa2f3`. The application was extracted to a temporary validation directory; the existing 1.12.1 build 30 installation was preserved. Strict bundle signature verification passed and the extracted plist reported 1.13/build 33. Native launch visibly displayed the 1.13 release-notes window without a commercial activation dialog in this launch. This is an existing-settings launch, not a clean first-run or expired-license migration proof.

The second Mac's packaged CLI also transcribed the same public JFK fixture with all process network access denied. It exited successfully; the resulting text was nonempty and contained “country”. Local evidence copy: `.build/verification/mini-offline-transcription.log`; no benchmark claim is made. Hardware dictation/insertion and selected-text commands are still unverified. Remote shared-screen observation worked, but remote input control returned `noWindowsAvailable`; the hardware test was handed to the owner. No configuration, permission or private key was changed to fabricate a passing scenario.

## Local interactive check and update-path exposure — 2026-11-10

The installed 1.12.1 build 32 instance on the primary workstation was stopped without replacing its bundle. The exact 1.13 build 33 candidate was launched, its running executable path verified, and its native release-notes window observed. Manual testing confirmed real microphone dictation and insertion into another application worked. This is an owner-observed functional check, not an independently recorded audio benchmark or a clean first-run/expired-client test.

Update publication is authorized as a controlled production-path check from the retained old installation. The legacy licensing backend remains operational until the update path is observed working. This exposure proceeds before the previously specified old-client update check can complete; it is an explicit release-sequence exception, not a retroactive pass. Clean first-run, an explicitly absent/expired commercial state, and selected-text command scenarios remain unverified. Publish no claim that those checks completed.

## Exposure and claims hardening — 2026-11-10

At target `5e59227050cd0ebbc8352b4eaab0d8a8e6fd7e66`, the independent exposure review reported **no findings** in its bounded scan of tracked files, reachable historical document/script/config/Swift versions, asset metadata and public-repository metadata. Targeted screening is not exhaustive semantic inspection of every historical blob. Local checkpoint refs are outside the intended HEAD/tag publication set and will not be pushed. The existing studio-site repository remains private.

Critical claims verification also reported **no findings** for CV.1–CV.8 at that target, using a separate configured reviewer model (`gpt-6-astra`) as an in-host hardening pass; no cross-provider diversity is claimed. Actual gate output, source/package identities, transcripts, input enumeration and four independent no-findings receipts were inspected. Older temporary site logs were unavailable, so source-identical Worker/build gates were rerun and retained under the private ignored review directory: six tests passed;65 pages built. Historical transient outputs were not fabricated.

The explicit public-ref secret-pattern scan used `gitleaks git --log-opts="HEAD --tags" --redact`; the tool reported284 scanned commits and no findings, while Git reachability enumeration reported290. These are different predicates and are not equated. The earlier all-ref scanner output297 includes non-public local refs. Publication will use explicit main and release-tag refspecs. These bounded checks do not assert absolute absence of private data or vulnerabilities.
