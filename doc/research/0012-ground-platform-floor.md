# GROUND-0012: Match future builds to the observed macOS baseline

**Status:** recorded
**Decision:** Use the exact macOS 27.2.1 baseline consistently in the package, app, build and future update feed.
**Decision ref:** doc/adr/0002-macos-support-baseline.md
**Confidence:** Strong
**Stakes:** medium × reversible

## Decision and confidence

Use Swift Package Manager's string platform initializer for the patch-level minimum, LSMinimumSystemVersion for Launch Services, and the same plist value for explicit Xcode deployment settings and future Sparkle feed generation (A1, A2, A3, B1). The project already declares platforms in Package.swift, copies its source plist into assembled bundles, and generates its own appcast (C1). Earlier model work preserved 14.0 (D1); this is a deliberate support-policy change for subsequent builds, not a correction to that historical evidence. The owner authorized the observed-host baseline. Existing public 1.14 remains unchanged. Proceed with focused metadata and toolchain validation; no broad application or audio changes.

## Evidence

### E1 — A patch-level platform requirement is supported by the canonical APIs

**Tier:** Primary
**Strength:** Medium
**Provenance:** A1, A2, A3, B1

SPM accepts two or three integer components in its string initializer; Apple defines LSMinimumSystemVersion as the required macOS release; Sparkle documents a three-component minimumSystemVersion. The reference implementation constructs MacOSVersion from the provided string: `return SupportedPlatform(platform: .macOS, version: SupportedPlatform.MacOSVersion(string: versionString).version)` (B1). There is no requirement to invent a .v27_2_1 enum case.

### E2 — The available operating-system baseline is 27.2.1

**Tier:** Measurement
**Strength:** High
**Provenance:** C2

`sw_vers` returned ProductVersion 27.2.1 and BuildVersion 26B131. `xcrun swift --version` returned Apple Swift 6.4.2, target arm64-apple-macosx27.2.0; `xcrun --sdk macosx --show-sdk-version` returned 27.2. These identify OS, compiler target and SDK separately. Minimal compilation must confirm that deployment 27.2.1 is retained in Mach-O rather than assuming SDK patch equality.

### E3 — The current project has separate build and update metadata surfaces

**Tier:** Measurement
**Strength:** High
**Provenance:** C1, D1

The package declares .v14; Info.plist has no minimum key; build-app.sh copies that plist; release.sh hardcodes the Sparkle minimum14.0. Align future paths by adding the app minimum, changing the SPM declaration and reading the plist minimum into build/feed generation. Do not modify dependencies' own deployment metadata or old research receipts.

## Plan and frozen evaluation

1. Add a focused configuration smoke that checks the resolved manifest minimum, app minimum, actual future-feed XML rendered from the existing release template, and a tiny executable's Mach-O deployment minimum. Run it against the unchanged source to observe RED.
2. Update only platform configuration and current platform documentation. Derive build/feed minimum from the app plist. Leave app version/build, release notes, application logic and public1.14 untouched.
3. Require GREEN for the smoke, plist/shell syntax checks and a fresh-context delta review. The smoke's tiny executable is a toolchain probe, not a rebuilt Fala app. Full next-release assembly remains a separate gate. No push, installation or publication in this scope.

## Source register

- **A1:** https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html#supportedplatform — string macOS minimum accepts two or three components (accessed 2026-11-10 via web open, lines71–79).
- **A2:** https://developer.apple.com/documentation/bundleresources/information-property-list/lsminimumsystemversion.md — app's minimum supported macOS release (accessed 2026-11-10 via web open, lines21–33).
- **A3:** https://sparkle-project.org/documentation/publishing/ — minimum system version requirements use three components (accessed 2026-11-10 via web open, lines95–105).
- **B1:** https://github.com/swiftlang/swift-package-manager/blob/main/Sources/Runtimes/PackageDescription/SupportedPlatforms.swift#L107-L120 — actual string initializer (accessed 2026-11-10 via raw source web open).
- **C1:** Package.swift:53; scripts/build-app.sh:163; scripts/release.sh:208; Sources/Fala/Resources/Info.plist — existing declaration, staging and feed paths (accessed 2026-11-10 via local read).
- **C2:** macOS 27.2.1 build26B131, Apple Swift6.4.2, macOS SDK27.2; reproduce with `sw_vers`, `xcrun swift --version`, `xcrun --sdk macosx --show-sdk-version` (accessed 2026-11-10 via local CLI; observed public release identities, not hardware inference).
- **D1:** `git log --all --oneline -- Package.swift scripts/build-app.sh README.md`; cc4a29f preserves14.0 while introducing Ultra No prior 27.2.1 support-policy change found (accessed 2026-11-10 via git log).

## Limitations and reversal

No macOS14 runtime test is claimed or required by the new policy. No future OS runtime compatibility is proven. The published1.14 is unaffected. Reconsider the policy only through an explicit supported-baseline decision and corresponding validation; do not silently infer it from changing developer hardware.

## Audit path

Run `node /Users/ale/.agents/skills/ad-ground/scripts/validate-record.mjs doc/research/0012-ground-platform-floor.md`, then reopen sources A1–D1. The planned smoke records actual toolchain acceptance independently of documentation.

## Observed evaluation

RED: the unchanged manifest reported14.0 instead of27.2.1 and the existing feed template did not derive the app minimum. The compiler probe already accepted27.2.1. After the bounded configuration change, all four focused checks passed: actual manifest/plist agreement, rendered future-feed XML, staged-bundle rejection of a14.0 binary and acceptance of27.2.1, and executable Mach-O27.2.1 retention plus local execution. The staged bundle uses placeholder resources to isolate deployment metadata; it is not a built or signed Fala candidate. Shell syntax, plist syntax and diff whitespace also passed. Receipts: `.agentic/reviews/platform-policy-red.log` and `platform-policy-green.log` in the implementation worktree.

The platform requirement in the source is now27.2.1. No Fala build, release or runtime benchmark was performed in this bounded change. A next delivery must run the full assembled-application gate. The website remains untouched while it distributes the immutable1.14 release; its EN/PT platform strings will need coordination with a future release.

## Integration closure

Original platform review found one Spec concern: the minimum-version guard followed staging codesign despite the before-sign contract. The delta moved validation after copies/rpath and before any codesign; five smoke cases pass, including invalid14.0 rejection without signing and valid27.2.1 continuation. Independent final review reports Standards0/Spec0 on full patch d1998a31985ce656b299033ac3b5a9b2ee593534af1dbc5fe04242271b2c29f4. Original concern is resolved, not omitted. Actual integrated app now builds with Info/Mach-O27.2.1; public1.14 min14 remains immutable.

Review provenance: summaries forwarded by the orchestrator from independent fresh-context reviewers; execution receipts are under `.agentic/reviews/priority-*`. This addendum records local integration evidence, not an additional source review or release.
