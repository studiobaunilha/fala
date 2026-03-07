#!/usr/bin/env bash
# Quick dev loop: build (debug) → copy to bundle → relaunch.
# Use this instead of install.sh during development.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SWIFT_WRAPPER="$REPO_DIR/scripts/swift-env.sh"
APP_BUILDER="$REPO_DIR/scripts/build-app.sh"

echo "▶ Running tests…"
bash "$SWIFT_WRAPPER" test

echo "▶ Building app bundle (debug via xcodebuild)…"
bash "$APP_BUILDER" debug --open

echo "✓ Running. Check menu bar."
