#!/usr/bin/env bash
# scripts/create-dmg.sh — Create a compressed DMG by mounting a writable image,
# copying the staged contents manually, and converting it to UDZO.
#
# This avoids `hdiutil create -srcfolder`, which can fail with signed app bundles
# on recent macOS versions with "Operation not permitted".

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKGROUND_SOURCE="$REPO_DIR/Assets/dmg-background.png"
VOLUME_ICON_SOURCE="$REPO_DIR/Sources/Fala/Resources/AppIcon.icns"
STYLE_SCRIPT="$REPO_DIR/scripts/style-dmg.applescript"
BACKGROUND_NAME="installer-background.png"

usage() {
    cat <<'EOF' >&2
usage: scripts/create-dmg.sh <volume-name> <stage-dir> <output-dmg>
EOF
    exit 1
}

VOLUME_NAME="${1:-}"
STAGE_DIR="${2:-}"
OUTPUT_DMG="${3:-}"

if [[ -z "$VOLUME_NAME" || -z "$STAGE_DIR" || -z "$OUTPUT_DMG" ]]; then
    usage
fi

if [[ ! -d "$STAGE_DIR" ]]; then
    echo "error: diretório de stage não encontrado: $STAGE_DIR" >&2
    exit 1
fi

if [[ ! -f "$BACKGROUND_SOURCE" ]]; then
    echo "error: background do DMG não encontrado: $BACKGROUND_SOURCE" >&2
    exit 1
fi

if [[ ! -f "$VOLUME_ICON_SOURCE" ]]; then
    echo "error: ícone de volume do DMG não encontrado: $VOLUME_ICON_SOURCE" >&2
    exit 1
fi

if [[ ! -f "$STYLE_SCRIPT" ]]; then
    echo "error: script de estilo do DMG não encontrado: $STYLE_SCRIPT" >&2
    exit 1
fi

APP_BUNDLE_PATH="$(find "$STAGE_DIR" -mindepth 1 -maxdepth 1 -type d -name '*.app' -print -quit)"
if [[ -z "$APP_BUNDLE_PATH" ]]; then
    echo "error: nenhum app bundle encontrado no stage do DMG" >&2
    exit 1
fi

APP_BUNDLE_NAME="$(basename "$APP_BUNDLE_PATH")"

WORK_DIR="$(mktemp -d -t fala-dmg.XXXXXX)"
RW_DMG="$WORK_DIR/disk-image-rw.dmg"
MOUNT_POINT=""
DEVICE_NAME=""

cleanup() {
    if [[ -n "$DEVICE_NAME" ]]; then
        hdiutil detach "$DEVICE_NAME" -force >/dev/null 2>&1 || true
        sleep 1
        hdiutil detach "$DEVICE_NAME" -force >/dev/null 2>&1 || true
    elif [[ -n "$MOUNT_POINT" ]] && mount | grep -q "on $MOUNT_POINT "; then
        hdiutil detach "$MOUNT_POINT" -force >/dev/null 2>&1 || true
    fi
    rm -rf "$WORK_DIR"
}

trap cleanup EXIT

STAGE_SIZE_KB=$(du -sk "$STAGE_DIR" | awk '{print $1}')
STAGE_SIZE_MB=$(( (STAGE_SIZE_KB + 1023) / 1024 ))
IMAGE_SIZE_MB=$(( STAGE_SIZE_MB + (STAGE_SIZE_MB / 5) + 64 ))

hdiutil create -size "${IMAGE_SIZE_MB}m" -fs HFS+ -volname "$VOLUME_NAME" -ov "$RW_DMG" >/dev/null
if mount | grep -q "on /Volumes/$VOLUME_NAME "; then
    hdiutil detach "/Volumes/$VOLUME_NAME" -force >/dev/null 2>&1 || true
    sleep 1
fi
ATTACH_OUTPUT="$(hdiutil attach "$RW_DMG" -nobrowse)"
ATTACH_MOUNT_LINE="$(printf '%s\n' "$ATTACH_OUTPUT" | awk '/\/Volumes\// { print; exit }')"
DEVICE_NAME="$(printf '%s\n' "$ATTACH_MOUNT_LINE" | awk '{ print $1 }')"
if [[ -z "$DEVICE_NAME" ]]; then
    echo "error: falha ao descobrir o device do volume montado" >&2
    exit 1
fi
MOUNT_POINT="$(printf '%s\n' "$ATTACH_MOUNT_LINE" | awk '{ print $NF }')"
if [[ -z "$MOUNT_POINT" || ! -d "$MOUNT_POINT" ]]; then
    echo "error: falha ao descobrir o ponto de montagem do volume" >&2
    exit 1
fi

find "$STAGE_DIR" -mindepth 1 -maxdepth 1 -print0 | while IFS= read -r -d '' entry; do
    name="$(basename "$entry")"
    destination="$MOUNT_POINT/$name"
    if [[ -L "$entry" ]]; then
        ln -s "$(readlink "$entry")" "$destination"
    else
        ditto "$entry" "$destination"
    fi
done

mkdir -p "$MOUNT_POINT/.background"
cp "$BACKGROUND_SOURCE" "$MOUNT_POINT/.background/$BACKGROUND_NAME"

cp "$VOLUME_ICON_SOURCE" "$MOUNT_POINT/.VolumeIcon.icns"

sync
sleep 4
/usr/bin/osascript "$STYLE_SCRIPT" "$VOLUME_NAME" "$APP_BUNDLE_NAME"
SetFile -a V "$MOUNT_POINT/.background"
SetFile -a V "$MOUNT_POINT/.background/$BACKGROUND_NAME"
SetFile -a V "$MOUNT_POINT/.VolumeIcon.icns"
SetFile -a C "$MOUNT_POINT"
hdiutil detach "$DEVICE_NAME" >/dev/null
DEVICE_NAME=""
MOUNT_POINT=""
mkdir -p "$(dirname "$OUTPUT_DMG")"
hdiutil convert "$RW_DMG" -format UDZO -o "$OUTPUT_DMG" >/dev/null
