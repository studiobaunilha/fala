# GROUND-0004: Recover Sparkle updates for an application-style cache path

Status: diagnosis and corrective implementation in progress; no completed updater migration claim.

## Observed failure and loop

The installed1.12.1/build32 updater downloaded the1.13 candidate but failed before archive extraction. Unified logs show Autoupdate unable to create `Library/Caches/dev.fala.app/org.sparkle-project.Sparkle/Installation`: Cocoa513 / POSIX1 (Operation not permitted), followed by installer timeout. Parent directories are user-owned0755; host, Autoupdate and Updater have the same Developer ID team; the host is not App Sandbox enabled. Private logs stay under ignored `.agentic/reviews/2026-11-10-updater-*.log`.

The original reproduction is the genuine installed application's Check Now → install path. A fast unattended public seam does not expose Sparkle's private cache-directory policy; dynamic invocation of SPULocalCacheDirectory was attempted but the private method is not runtime-accessible. Do not claim that failed probe reproduced the native bug. Upstream's confirmed reproduction plus the exact matching consumer error grounds the targeted dependency correction; the final native update remains the deciding integration check.

A separate packaging regression is testable through Foundation's public Bundle API: the actual distribution plist is assembled into a temporary executable bundle and must identify itself as APPL with a resolvable executable. The new AppBundleMetadataTests test failed on missing APPL before the fix. The candidate was classified as a generic bundle by codesign; explicit executable/application metadata will be restored. This is a separate packaging correction, not the cause claimed for the earlier cache-creation failure.

## Ranked hypotheses

1. Cache path mistaken for an application because the bundle ID ends in .app. Predict corrected Sparkle derives a non-.app cache directory and avoids that protection failure. Matching upstream fix is present in2.9.3.
2. Helper signing or sandbox mismatch. Predict differing team IDs or sandbox entitlements. Disfavored by actual signing/entitlement inspection: all teamJ69R5AA734, no host app sandbox.
3. Ordinary owner/ACL write denial. Predict wrong ownership/mode. Disfavored by user-owned0755 parent metadata; the actual helper receives EPERM, consistent with platform protection rather than POSIX ownership.
4. Corrupt download or archive metadata. Predict signature/digest mismatch or failure after extraction starts. Exact DMG hash/Ed25519 previously verified; current failure occurs before extraction. Explicit bundle metadata is independently being tightened.

## Four-source grounding

- Official docs: Sparkle2.9.3 release identifies the .app-ending-ID installation fix: https://github.com/sparkle-project/Sparkle/releases/tag/2.9.3. Apple documents executable/application bundle fields at https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleexecutable and https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundlepackagetype.
- Reference implementation: upstream merged PR2882 and versioned SPULocalCacheDirectory append .sparkle to the unsafe cache host directory, leaving application identity unchanged: https://github.com/sparkle-project/Sparkle/pull/2882 and https://raw.githubusercontent.com/sparkle-project/Sparkle/2.9.3/Sparkle/SPULocalCacheDirectory.m. Upstream reports native reproduction and correction with a notarized .app-suffix identifier.
- In-repo pattern: Package.resolved fixes the prior Sparkle revision; scripts/build-app.sh shallow-signs nested helpers separately and copies the distribution plist; BatchCLIIntegrationTests and source fixture tests provide the existing XCTest/Foundation stack. Preserve the real bundle identifier, preferences, update key and signing team.
- Git history: baselinebc10862 already pins Sparkle2.9.0 at21d8df80440b1ca3b65fa82e40782f1e5a9e6ba2. Build-signing historye80df60 explicitly preserves nested helper signing. This is not a new licensing path; retain the public free-release behavior.

## Decision and limits

Use the minimal released dependency correction, Sparkle2.9.3, and explicit app/executable plist metadata in a maintenance build. Avoid broad App Management or filesystem permission changes. The old installed updater cannot receive a framework fix until it installs a new app; bootstrap recovery must be verified separately (a safe cache-path repair or one manual signed-app replacement if required). Do not claim a change to the new package repairs an already-running old helper.

Evidence strength: primary release + versioned reference + exact consumer error and signature/metadata measurements. Confidence: proceed-with-mitigation; native update test still required. Version1.13.1/build34 will use new package/signature receipts; never overwrite immutable1.13 bytes or tag. Existing first-run/expired-state/selection limits remain explicit. Site/payment retirement remains deferred until recovery is verified.

## Corrective candidate verification

Commit `cca50372d42efa7206a4595211ee7baa21c13604` contains the eight-file correction. The public Bundle API regression failed before the metadata change and passed afterward. The mandatory full gate passed286 XCTest cases and strict lint with zero violations in184 Swift files. The release bundle was checked: app1.13.1/build34, explicit APPL/executable metadata, embedded Sparkle2.9.3 and strict Developer ID signature verification. Third-party notice version was updated; the upstream license text is unchanged and remains included.

Fresh-context correction review at that target reported **no findings** on Standards or Spec axes. It explicitly retained the old-helper bootstrap limitation. This was a delta review, not another review of the original licensing removal.

Apple notarization Accepted, submission `01679f61-8418-4bb9-b5ab-c41d325e6cf6`; staple validation passed. The exact stapled DMG is18293578bytes, SHA-256 `2b20e54eac770f0eddda6d80d351ff1ce058155f6b8e871a3c00fada484e6746`. It was signed on the original signing host without exporting the private key, and its Ed25519 signature was independently verified against the retained installed application's public key. These checks verify the maintenance candidate, not successful installation by the old updater; that native result is still pending.
