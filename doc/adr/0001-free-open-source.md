# ADR-0001: Distribute Fala free under MIT

**Status:** accepted
**Date:** 2026-11-09
**Deciders:** Project owner

## Context

People should be able to download and use Fala without payment or activation. The owner approved free distribution, publication of the application source and the MIT license. Commercial activation currently blocks local workflows and introduces a server dependency unrelated to transcription.

## Decision

Distribute the official Fala application free of charge and publish the project source under MIT. Remove commercial activation, trials, device limits and payment flows from the application and website. Preserve Apple signing, notarization and signed Sparkle updates. Third-party components and downloaded models retain their own terms.

The Studio Baunilha website repository remains private. Preserve existing commercial records; removal of runtime licensing does not authorize database deletion or rewriting Git history.

## Consequences

The application no longer requires commercial credentials or server validation. MIT permits reuse, redistribution and commercial derivatives, including closed-source derivatives, subject to its notice requirements. Release publication requires the approved verification plan, review of the material being exposed and the final publication gate.

## Alternatives Considered

- Free proprietary distribution: rejected after the owner chose open source.
- GPLv3: considered; the owner selected MIT for adoption and reuse.
- A permanently active simulated Pro license: rejected because it retains a subsystem that no longer serves the product.

## Evidence

The implementation basis is recorded in [GROUND-0001](../research/0001-ground-free-open-source.md). Release evaluation is defined in [PRISM-0002](../research/0002-prism-free-open-source-release.md).
