#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVELOPER_DIR_VALUE="${DEVELOPER_DIR:-$(bash "$REPO_DIR/scripts/xcode-dir.sh")}"
DERIVED_DATA="$REPO_DIR/.xcodebuild-tests"

exec /usr/bin/env -u SDKROOT DEVELOPER_DIR="$DEVELOPER_DIR_VALUE" \
    xcodebuild \
        -scheme Fala \
        -destination "platform=macOS" \
        -derivedDataPath "$DERIVED_DATA" \
        test \
        -only-testing:FalaTests/MLXSmokeTests
