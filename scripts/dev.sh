#!/usr/bin/env bash
# Quick dev loop: build (debug) → copy to bundle → relaunch.
# Use this instead of install.sh during development.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE_BINARY="$HOME/Applications/Fala.app/Contents/MacOS/Fala"
SWIFT_WRAPPER="$REPO_DIR/scripts/swift-env.sh"

echo "▶ Running tests…"
bash "$SWIFT_WRAPPER" test

echo "▶ Building (debug)…"
bash "$SWIFT_WRAPPER" build

echo "▶ Copying to bundle…"
cp "$REPO_DIR/.build/debug/Fala" "$BUNDLE_BINARY"

echo "▶ Relaunching…"
pkill Fala 2>/dev/null || true
sleep 0.3
open "$HOME/Applications/Fala.app"

echo "✓ Running. Check menu bar."
