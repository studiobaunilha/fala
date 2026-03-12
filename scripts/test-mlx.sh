#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVELOPER_DIR_VALUE="${DEVELOPER_DIR:-$(bash "$REPO_DIR/scripts/xcode-dir.sh")}"
TMP_DIR="$(mktemp -d -t fala-mlx-smoke.XXXXXX)"
APP_DIR="$TMP_DIR/Fala.app"

cleanup() {
    rm -rf "$TMP_DIR"
}

trap cleanup EXIT

DEVELOPER_DIR="$DEVELOPER_DIR_VALUE" \
    bash "$REPO_DIR/scripts/build-app.sh" release --app-dir "$APP_DIR"

exec "$APP_DIR/Contents/MacOS/Fala" mlx-smoke
