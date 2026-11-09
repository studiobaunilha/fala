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
- Sparkle: NOT SIGNED. `sign_update` exited 1 because the existing ed25519 signing key was not found; service-scoped Keychain metadata lookup also returned item-not-found. No key was generated, exported or rotated. No final appcast was created.
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

1. Fresh-context review of app runtime, distribution and website; critical claims hardening. Four bounded review packets were prepared, but no independent reviewer has run.
2. Recover the original Sparkle private key through a secure local path, sign the exact stapled DMG, and verify against the existing `SUPublicEDKey`; preserve that key.
3. Real packaged first-run, hardware dictation and selected-text commands; update from an installation with absent/expired commercial state in an isolated environment. Window/unit tests and offline CLI do not retire these scenarios.
4. Authenticate personal Cloudflare in an isolated configuration and verify the intended account; inspect the live Paddle catalog and pending events before stopping sales/removing runtime. Current public checkout configuration is live. Removing local site buttons is not provider closure.
5. Complete content/exposure review and final exact-set scan, then present the concrete publication packet and receive final exposure authorization. Preserve the private studio-site repository.
6. After publication: anonymous source/tag access, exact public download hash, live site/legacy routes, update feed and actual no-new-sales state. No deployed result is asserted yet.

A release executable launched from a read-only working directory prints an LLVM profile-file diagnostic while `--help` exits 0. A trial coverage flag did not retire it and was removed; no ineffective workaround was shipped. Its provenance was not established. This observation is retained separately from licensing behavior.

Local logs and ignored review packets are working evidence, not permanent public attachments. This tracked record preserves the observations, identities and limitations needed to reproduce or reassess them.
