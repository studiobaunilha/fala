#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-dev}"

if [[ -n "${FALA_CODESIGN_IDENTITY:-}" ]]; then
    printf "%s\n" "$FALA_CODESIGN_IDENTITY"
    exit 0
fi

IDENTITIES="$(security find-identity -v -p codesigning 2>/dev/null || true)"

pick_identity() {
    local prefix="$1"
    printf "%s\n" "$IDENTITIES" | awk -F'"' -v prefix="$prefix" '
        $2 ~ ("^" prefix) {
            if (match($0, /[0-9A-F]{40}/)) {
                print substr($0, RSTART, RLENGTH)
                exit
            }
        }
    '
}

case "$MODE" in
    release)
        IDENTITY="$(pick_identity "Developer ID Application:")"
        if [[ -z "$IDENTITY" ]]; then
            IDENTITY="$(pick_identity "Apple Distribution:")"
        fi
        if [[ -z "$IDENTITY" ]]; then
            IDENTITY="$(pick_identity "Apple Development:")"
        fi
        ;;
    dev|debug)
        IDENTITY="$(pick_identity "Apple Development:")"
        if [[ -z "$IDENTITY" ]]; then
            IDENTITY="$(pick_identity "Developer ID Application:")"
        fi
        if [[ -z "$IDENTITY" ]]; then
            IDENTITY="$(pick_identity "Apple Distribution:")"
        fi
        ;;
    *)
        echo "usage: scripts/codesign-identity.sh <dev|debug|release>" >&2
        exit 1
        ;;
esac

if [[ -n "$IDENTITY" ]]; then
    printf "%s\n" "$IDENTITY"
    exit 0
fi

echo "warning: nenhuma identidade de assinatura estável encontrada; usando assinatura adhoc" >&2
printf "%s\n" "-"
