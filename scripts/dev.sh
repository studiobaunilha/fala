#!/usr/bin/env bash
# Quick dev loop: build (debug) → copy to bundle → relaunch.
# Use this instead of install.sh during development.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE_BINARY="$HOME/Applications/Sussurro.app/Contents/MacOS/Sussurro"

echo "▶ Running tests…"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test

echo "▶ Building (debug)…"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build

echo "▶ Copying to bundle…"
cp "$REPO_DIR/.build/debug/Sussurro" "$BUNDLE_BINARY"

echo "▶ Relaunching…"
pkill Sussurro 2>/dev/null || true
sleep 0.3
open "$HOME/Applications/Sussurro.app"

echo "✓ Running. Check menu bar."
