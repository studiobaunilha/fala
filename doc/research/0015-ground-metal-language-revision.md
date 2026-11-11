# GROUND-0015: Select a compatible Metal language for the pinned MLX kernels

**Status:** recorded
**Decision:** Pass MTL_LANGUAGE_REVISION=Metal32 to Xcode app assembly while preserving macOS27.2.1 deployment.
**Decision ref:** doc/adr/0002-macos-support-baseline.md
**Confidence:** Strong
**Stakes:** medium × reversible

## Decision and confidence

Use Xcode's supported Metal language-revision setting to compile the pinned MLX0.30.6 kernels as MSL3.2 (A1,B1). Do not edit vendor headers, lower OSdeployment or suppress diagnostics. Existing build-app.sh already supplies explicit Xcode build settings (C1). The app build failed under deployment-driven Metal language selection; a same-kernel/compiler/target probe changed only the language flag and retired that failure (C2). Earlier quality work kept bundled MLX verification separate from unit tests (D1); this fix still requires the assembled MLX runtime gate before claiming application readiness.

## Evidence

### E1 — Xcode supplies a canonical Metal-only language setting

**Tier:** Primary
**Strength:** Medium
**Provenance:** A1, B1

Apple documents MTL_LANGUAGE_REVISION separately from deployment and warning flags. Installed Xcode27.2 MetalCompiler.xcspec declares DefaultValue=UseDeploymentTarget and maps Metal32 directly to -std=metal3.2. It affects Metal compilation, not Swift/C++ language or the macOS minimum. This avoids inventing a raw OTHER_METAL_FLAGS name or the invalid legacy macos-metal3.2 dialect. Project app assembly builds MLX's Metal files through Xcode, matching this compiler specification.

### E2 — The actual pinned attention kernel fails by default and compiles with3.2

**Tier:** Measurement
**Strength:** High
**Provenance:** C2

Integrator's unchanged steel_attention.metal from mlx-swift0.30.6 revision6ba4827fb82c97d012eec9ab4b2de21f85c3b33d, same Metal27.2toolchain and air64-apple-macos27.2.1 target: default compileexit1 with address-space/reference-binding errors; -std=metal3.2 exit0. The initial -std=macos-metal3.2 spelling was explicitly recorded as setup error, not a deciding result. Vendor source was not altered.

### E3 — Generated kernels and runtime readiness remain separate concerns

**Tier:** Primary
**Strength:** Medium
**Provenance:** A2, C1, D1

The pinned package contains native Metal kernels and a generated metallib consumed by MLX. Selecting a source-language revision does not prove every kernel or model executes correctly. The existing real assembled-app MLX smoke remains necessary after full app assembly. No model quality/performance or future-OS support claim follows from the compile probe.

## Diagnosis, plan and frozen evaluation

Observed fullapp failure: MLX steel attention references reject default language semantics at the new unchanged27.2.1 floor. H1: deployment-driven language selection causes the error; explicit3.2 should remove it. H2: compiler/source fails regardless of language;3.2 would also fail. H3: stale/modified generatedsource caused it; kernel pin/hash would differ. Integrator's same-input direct compiler controls supportH1 and falsifyH2. Preserve those red logs; verify package/kernel identity to retireH3.

Before changing production script: create an ignored minimal Xcode static-library target referencing the original kernel by absolute path and a trivial Ctranslationunit, using the same deployment27.2.1. Run default→RED and MTL_LANGUAGE_REVISION=Metal32→GREEN, retain the actual compiler command containing -std=metal3.2 and unchanged air64-apple-macos27.2.1. This proves Xcode setting propagation, not just a handwritten compiler flag. Then add the one buildsetting argument to build-app.sh, syntaxcheck/diffcheck and review only that line plus this record. Do not repeat324tests for configuration-only change; integrator runs the final assembled-app build and MLX runtime smoke. No release/installation/publication.

## Source register

- **A1:** https://developer.apple.com/documentation/xcode/build-settings-reference.md#Metal-Language-Revision — MTL_LANGUAGE_REVISION selects the Metal language revision, documented separately from deployment and diagnostic settings (accessed 2026-11-10 via webopen/find, lines3047–3051).
- **A2:** https://raw.githubusercontent.com/ml-explore/mlx-swift/0.30.6/Package.swift and https://raw.githubusercontent.com/ml-explore/mlx/v0.30.6/mlx/backend/metal/kernels/CMakeLists.txt — pinned wrapper/native kernels, kernel build and metallib artifact; native reference explicitly registers steel_attention (accessed 2026-11-10 via webopen).
- **B1:** Xcode27.2 build27B52, Contents/SharedFrameworks/XCBuild.framework/Versions/A/PlugIns/XCBBuildService.bundle/Contents/PlugIns/XCBSpecifications.ideplugin/Contents/Resources/MetalCompiler.xcspec:254–307 — compiler implementation maps UseDeploymentTarget to no explicit standard and Metal32 to -std=metal3.2. Reproduce by reading this public installed specification after `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -version` (accessed 2026-11-10 via localread).
- **C1:** scripts/build-app.sh:89–101 supplies explicit deployment and warnings-as-errors build settings; scripts/test-mlx.sh checks the assembled MLX bundle (accessed 2026-11-10 via localread).
- **C2:** Integration checkout .agentic/reviews/priority-metal-language-probe.json and priority-metal-probe-default.log; .xcodebuild-release/SourcePackages/checkouts/mlx-swift gitdescribe0.30.6/revision6ba4827; Metaltoolchain27.2.47.0; SDK27.2; reproduce exact argv from receipt (accessed 2026-11-10 via localread/CLI).
- **D1:** 544df5d scripts/build-app.sh/scripts/test-mlx.sh establishes packaged MLX smoke; `git log --all --grep=Metal` found no previous Metal-language pin in project buildscript (accessed 2026-11-10 via gitlog).

## Limitations and reversal

This is compatibility configuration for the existing dependency, not an optimization or vendor fix. The generated fixture is not the Fala application. Full packaged compile/runtime validation remains mandatory. Reconsider this pin with a future MLX/toolchain update using equivalent kernel/runtime evidence rather than changing it silently. No OSminimum, appversion, source dependency pin or published1.14 bytes are changed.

## Audit path

Validate the ground record before the production edit; review the resulting two-file delta once. Keep original failed app/direct-compiler controls and the new Xcode propagation receipt.

## Observed Xcode propagation

A minimal native Xcode target referenced the exact failing kernel in the integrator checkout without copying or editing it. With deployment27.2.1 and no Metal override, Xcode exited65 and the actual CompileMetalFile command failed with the same address-space/reference-binding errors. With only MTL_LANGUAGE_REVISION=Metal32 added, Xcode exited0, compiled the kernel with -std=metal3.2 and -targetair64-apple-macos27.2.1, linked default.metallib and completed the native target. Kernel SHA256 remained identical before and after. This retires the propagation risk independently of the prior handwritten compiler-flag probe. No vendor/model/deployment/warning setting changed.

Evidence: `.agentic/reviews/metal-xcode-propagation.json` includes exact commands, sourcehash and metallibhash; `metal-xcode-default.log` preserves RED and `metal-xcode-metal32.log` preserves GREEN. The ignored project/derived data live under `.build/metal-language-propagation`. Production patch is the one canonical Xcode setting argument in scripts/build-app.sh. Shell syntax/diff checks follow. Full Fala assembly and packaged MLX runtime are still the integrator's next gates; the minimal kernel target does not replace them.

## Integration closure

Independent review of two-file Metal-setting delta 2c33b45839ede9a3b311690793242c8bb8c22fa92bf9d3e54c019b138b04cd1b reports Standards0/Spec0. Integrated app BUILD SUCCEEDED with target27.2.1 and Metal32; the exact packaged default.metallib was loaded and its existing argmin_float32 kernel executed once on GPU over16synthetic values, returning expected unique minimumindex7. An initial arange probe was unsuitable because that function is JIT-only/not packaged; no kernel ran in that attempt. This single dispatch does not prove MLX C++ dispatch, every kernel or LLM inference/quality. No LLM model downloaded, no public artifact mutated.

Review provenance: summaries forwarded by the orchestrator from independent fresh-context reviewers; execution receipts are under `.agentic/reviews/priority-*`. This addendum records local integration evidence, not an additional source review or release.
