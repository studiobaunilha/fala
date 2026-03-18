#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVELOPER_DIR_VALUE="${DEVELOPER_DIR:-$(bash "$REPO_DIR/scripts/xcode-dir.sh")}"
XCTEST_INCLUDE_DIR="${DEVELOPER_DIR_VALUE}/Platforms/MacOSX.platform/Developer/usr/lib"
XCTEST_FRAMEWORK_DIR="${DEVELOPER_DIR_VALUE}/Platforms/MacOSX.platform/Developer/Library/Frameworks"
XCTEST_PRIVATE_FRAMEWORK_DIR="${DEVELOPER_DIR_VALUE}/Platforms/MacOSX.platform/Developer/Library/PrivateFrameworks"

run_swift() {
    exec /usr/bin/env -u SDKROOT DEVELOPER_DIR="$DEVELOPER_DIR_VALUE" /usr/bin/swift "$@"
}

run_swift_test() {
    exec /usr/bin/env -u SDKROOT DEVELOPER_DIR="$DEVELOPER_DIR_VALUE" /usr/bin/swift test \
        -Xswiftc -I \
        -Xswiftc "$XCTEST_INCLUDE_DIR" \
        -Xswiftc -F \
        -Xswiftc "$XCTEST_FRAMEWORK_DIR" \
        -Xswiftc -F \
        -Xswiftc "$XCTEST_PRIVATE_FRAMEWORK_DIR" \
        -Xswiftc -warnings-as-errors \
        "$@"
}

case "${1:-}" in
    "")
        printf "usage: %s <swift-subcommand> [args...]\n" "${BASH_SOURCE[0]}" >&2
        exit 1
        ;;
    test)
        shift
        run_swift_test "$@"
        ;;
    *)
        run_swift "$@"
        ;;
esac
