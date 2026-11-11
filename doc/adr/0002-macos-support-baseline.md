# ADR-0002: Set the macOS support baseline

**Status:** accepted
**Date:** 2026-11-10
**Deciders:** Project owner
**Evidence ref:** ../research/0012-ground-platform-floor.md

## Context

Maintaining support for macOS releases without an available runtime increases the validation scope. The supported baseline should match the operating system available for local validation. The observed development Mac runs macOS 27.2.1, build 26B131. This is an operating-system requirement, independent of the Mac hardware model.

## Decision

We will require macOS 27.2.1 or later on Apple Silicon for subsequent builds of this source. Match Swift Package Manager deployment, the application's minimum-system metadata, build settings and future Sparkle update metadata to that exact baseline. Do not round down to 27.2 or 27.0.

The already published Fala 1.14 (35) remains immutable with its original minimum metadata of macOS 14.0. Its macOS 14 runtime was not tested. This decision does not authorize a new release or change its existing installer, tag or public feed.

## Consequences

Local validation targets an available operating-system baseline. Older macOS installations will not qualify for future updates requiring 27.2.1; they can retain the previously published release. Raising the minimum does not prove compatibility with every newer macOS release. Release validation still needs to exercise the assembled application.

## Alternatives Considered

- Preserve macOS 14 as the active baseline: rejected because validating that runtime is outside the chosen support scope.
- Set a major-only or minor-only minimum: rejected because either admits versions earlier than the observed 27.2.1 baseline.
- Rewrite the published 1.14 metadata or installer: rejected because approved artifacts remain immutable.
