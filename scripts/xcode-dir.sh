#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${DEVELOPER_DIR:-}" && -d "${DEVELOPER_DIR}" ]]; then
    printf '%s\n' "${DEVELOPER_DIR}"
    exit 0
fi

for candidate in \
    "/Applications/Xcode.app/Contents/Developer" \
    "/Volumes/MacMini/Applications/Xcode.app/Contents/Developer"
do
    if [[ -d "$candidate" ]]; then
        printf '%s\n' "$candidate"
        exit 0
    fi
done

selected="$(xcode-select -p 2>/dev/null || true)"
if [[ -n "$selected" && "$selected" != "/Library/Developer/CommandLineTools" ]]; then
    printf '%s\n' "$selected"
    exit 0
fi

printf '%s\n' "/Applications/Xcode.app/Contents/Developer"
