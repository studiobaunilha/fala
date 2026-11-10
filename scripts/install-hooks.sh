#!/usr/bin/env bash
# Instala os git hooks locais do projeto para o checkout usado pelo Git.
# Execute uma vez após clonar: bash scripts/install-hooks.sh
# Ou via Makefile: make hooks
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS_SRC="$REPO_DIR/scripts/hooks"
HOOKS_DST="$(git -C "$REPO_DIR" rev-parse --path-format=absolute --git-path hooks)"

if git -C "$REPO_DIR" config --get core.hooksPath >/dev/null; then
    printf 'error: core.hooksPath personalizado; preserve seus hooks e integre o gate do projeto manualmente.\n' >&2
    exit 1
fi

for hook in "$HOOKS_SRC"/*; do
    name="$(basename "$hook")"
    target="$HOOKS_DST/$name"
    if [[ -L "$target" ]]; then
        if [[ ! "$target" -ef "$hook" && "$(readlink "$target")" != "../../scripts/hooks/$name" ]]; then
            printf 'error: hook personalizado preservado: %s\n' "$target" >&2
            exit 1
        fi
    elif [[ -e "$target" ]] && ! grep -qFx '# Fala project hook dispatcher' "$target"; then
        printf 'error: hook personalizado preservado: %s\n' "$target" >&2
        exit 1
    fi
done

mkdir -p "$HOOKS_DST"
dispatcher=''
trap 'if [[ -n "$dispatcher" ]]; then rm -f "$dispatcher"; fi' EXIT

GREEN='\033[0;32m'
RESET='\033[0m'

for hook in "$HOOKS_SRC"/*; do
    name="$(basename "$hook")"
    target="$HOOKS_DST/$name"

    chmod +x "$hook"
    dispatcher="$(mktemp "$HOOKS_DST/.fala-hook.XXXXXX")"
    cat > "$dispatcher" <<'HOOK'
#!/usr/bin/env bash
# Fala project hook dispatcher
set -euo pipefail
REPO_DIR="$(git rev-parse --show-toplevel)"
HOOK_NAME="$(basename "${BASH_SOURCE[0]}")"
exec bash "$REPO_DIR/scripts/hooks/$HOOK_NAME" "$@"
HOOK
    chmod +x "$dispatcher"
    mv -f "$dispatcher" "$target"
    dispatcher=''
    printf "${GREEN}✓${RESET} Hook instalado: %s\n" "$target"
done

echo ""
echo "Hooks ativos. Serão executados automaticamente a cada commit."
