#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF' >&2
usage: scripts/build-app.sh <debug|release> [--open] [--app-dir /path/to/Fala.app]
EOF
    exit 1
}

MODE="${1:-}"
if [[ -z "$MODE" ]]; then
    usage
fi
shift || true

OPEN_AFTER_BUILD=0
APP="$HOME/Applications/Fala.app"
while (($#)); do
    case "$1" in
        --open)
            OPEN_AFTER_BUILD=1
            ;;
        --app-dir)
            shift || usage
            [[ -n "${1:-}" ]] || usage
            APP="$1"
            ;;
        *)
            usage
            ;;
    esac
    shift
done

case "$MODE" in
    debug)
        CONFIGURATION="Debug"
        DERIVED_DATA=".xcodebuild-debug"
        ;;
    release)
        CONFIGURATION="Release"
        DERIVED_DATA=".xcodebuild-release"
        ;;
    *)
        usage
        ;;
esac

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVELOPER_DIR_VALUE="${DEVELOPER_DIR:-$(bash "$REPO_DIR/scripts/xcode-dir.sh")}"
CODESIGN_IDENTITY="$(bash "$REPO_DIR/scripts/codesign-identity.sh" "${MODE}")"
PRODUCTS_DIR="$REPO_DIR/$DERIVED_DATA/Build/Products/$CONFIGURATION"
BINARY_SOURCE="$PRODUCTS_DIR/Fala"
BUNDLE_BINARY="$APP/Contents/MacOS/Fala"
METALLIB="$PRODUCTS_DIR/mlx-swift_Cmlx.bundle/Contents/Resources/default.metallib"
LOCALIZATION_BUNDLE="$PRODUCTS_DIR/Fala_FalaCore.bundle"
LOCALIZATION_CATALOG="$REPO_DIR/Sources/FalaCore/Resources/Localizable.xcstrings"
LOCALIZATION_VERIFY="$REPO_DIR/scripts/verify-localization-bundle.py"

build_with_xcode() {
    local log_file
    log_file="$(mktemp -t fala-xcodebuild.XXXXXX.log)"
    trap 'rm -f "$log_file"' RETURN

    filter_xcodebuild_noise() {
        python3 -c '
import re
import sys

skip_destination_block = False

for raw_line in sys.stdin:
    line = raw_line.rstrip("\r\n")
    normalized = line.strip()
    if "IDERunDestination: Supported platforms for the buildables in the current scheme is empty." in normalized:
        continue
    if normalized == "--- xcodebuild: WARNING: Using the first of multiple matching destinations:":
        skip_destination_block = True
        continue
    if skip_destination_block:
        if normalized.startswith("{ platform:"):
            continue
        skip_destination_block = False
    print(line)
'
    }

    if ! /usr/bin/env -u SDKROOT DEVELOPER_DIR="$DEVELOPER_DIR_VALUE" \
        xcodebuild \
            -scheme Fala \
            -configuration "$CONFIGURATION" \
            -destination "platform=macOS" \
            -derivedDataPath "$DERIVED_DATA" \
            SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
            GCC_TREAT_WARNINGS_AS_ERRORS=YES \
            CLANG_TREAT_WARNINGS_AS_ERRORS=YES \
            build >"$log_file" 2>&1; then
        filter_xcodebuild_noise < "$log_file" >&2
        if grep -q "missing Metal Toolchain" "$log_file"; then
            cat >&2 <<EOF
error: Metal Toolchain ausente. Instale com:
  DEVELOPER_DIR="$DEVELOPER_DIR_VALUE" xcodebuild -downloadComponent MetalToolchain
EOF
        fi
        exit 1
    fi

    filter_xcodebuild_noise < "$log_file"
}

verify_localization_bundle() {
    python3 "$LOCALIZATION_VERIFY" "$LOCALIZATION_CATALOG" "$1"
}

ensure_fresh_localizations() {
    if verify_localization_bundle "$LOCALIZATION_BUNDLE"; then
        return
    fi

    echo "warning: bundle de localização stale; refazendo build limpo..." >&2
    rm -rf "$REPO_DIR/$DERIVED_DATA"
    build_with_xcode
    verify_localization_bundle "$LOCALIZATION_BUNDLE"
}

assert_staged_path_exists() {
    local path="$1"
    local label="$2"

    if [[ ! -e "$path" ]]; then
        echo "error: $label ausente em $path" >&2
        exit 1
    fi
}

verify_staged_bundle_contents() {
    assert_staged_path_exists "$APP/Contents/MacOS/Fala" "binário principal"
    assert_staged_path_exists "$APP/Contents/Info.plist" "Info.plist"
    assert_staged_path_exists "$APP/Contents/Resources/AppIcon.icns" "ícone do app"
    assert_staged_path_exists "$APP/Contents/Resources/Fala_FalaCore.bundle" "bundle de recursos FalaCore"
    assert_staged_path_exists "$APP/Contents/Resources/mlx-swift_Cmlx.bundle/Contents/Resources/default.metallib" "metallib do runtime MLX"
    assert_staged_path_exists "$APP/Contents/Frameworks/Sparkle.framework" "Sparkle.framework"

    find "$PRODUCTS_DIR" -maxdepth 1 -type d -name '*.bundle' -print0 | while IFS= read -r -d '' bundle; do
        assert_staged_path_exists \
            "$APP/Contents/Resources/$(basename "$bundle")" \
            "bundle de recurso $(basename "$bundle")"
    done

    find "$PRODUCTS_DIR" -maxdepth 1 -type d -name '*.framework' -print0 | while IFS= read -r -d '' framework; do
        assert_staged_path_exists \
            "$APP/Contents/Frameworks/$(basename "$framework")" \
            "framework $(basename "$framework")"
    done
}

stage_bundle() {
    rm -rf "$APP"

    mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"

    cp "$BINARY_SOURCE" "$BUNDLE_BINARY"
    cp "$REPO_DIR/Sources/Fala/Resources/Info.plist" "$APP/Contents/"
    cp "$REPO_DIR/Sources/Fala/Resources/AppIcon.icns" "$APP/Contents/Resources/"

    find "$PRODUCTS_DIR" -maxdepth 1 -type d -name '*.bundle' -print0 | while IFS= read -r -d '' bundle; do
        cp -R "$bundle" "$APP/Contents/Resources/"
    done

    find "$PRODUCTS_DIR" -maxdepth 1 -type d -name '*.framework' -print0 | while IFS= read -r -d '' framework; do
        cp -R "$framework" "$APP/Contents/Frameworks/"
    done

    install_name_tool -add_rpath @executable_path/../Frameworks "$BUNDLE_BINARY" 2>/dev/null || true

    local entitlements_path="$REPO_DIR/scripts/Fala.entitlements"

    # Step 1: Sign inner components FIRST from the inside-out (-depth)
    # We do NOT use --deep or --entitlements here, as injecting our global app entitlements
    # into Sparkle XPC services corrupts their signature and breaks macOS TCC Accessibility.
    find "$APP" -depth \( -type d \( -name "*.framework" -o -name "*.bundle" -o -name "*.xpc" -o -name "*.app" \) -o -type f \( -name "*.dylib" -o -name "Autoupdate" \) \) -print0 | while IFS= read -r -d '' component; do
        if [[ "$component" == "$APP" ]]; then continue; fi # Skip root app, we sign it shallowly later
        codesign --force --options runtime --timestamp --sign "$CODESIGN_IDENTITY" "$component"
    done
    
    # Step 2: Sign the outer application bundle SHALLOWLY with our global entitlements
    codesign --force --options runtime --timestamp --entitlements "$entitlements_path" --sign "$CODESIGN_IDENTITY" "$APP"
}

build_with_xcode

if [[ ! -f "$METALLIB" ]]; then
    echo "error: MLX metallib não foi gerada em $METALLIB" >&2
    exit 1
fi

if [[ ! -f "$BINARY_SOURCE" ]]; then
    echo "error: binário do app não encontrado em $BINARY_SOURCE" >&2
    exit 1
fi

ensure_fresh_localizations

stage_bundle
verify_staged_bundle_contents

verify_localization_bundle "$APP/Contents/Resources/Fala_FalaCore.bundle"

if [[ "$OPEN_AFTER_BUILD" -eq 1 ]]; then
    pkill Fala 2>/dev/null || true
    sleep 0.3
    tccutil reset Accessibility dev.fala.app 2>/dev/null || true
    open "$APP"
fi

printf "✓ App empacotado em %s\n" "$APP"
