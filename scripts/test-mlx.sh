#!/usr/bin/env bash
set -euo pipefail

DEFAULT_XCODE="/Applications/Xcode.app/Contents/Developer"
DEVELOPER_DIR_VALUE="${DEVELOPER_DIR:-$DEFAULT_XCODE}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="$REPO_DIR/.xcodebuild-tests"

exec /usr/bin/env -u SDKROOT DEVELOPER_DIR="$DEVELOPER_DIR_VALUE" \
    xcodebuild \
        -scheme Fala \
        -destination "platform=macOS" \
        -derivedDataPath "$DERIVED_DATA" \
        test \
        -only-testing:FalaTests/MLXSmokeTests/testMLXQwenSmoke
