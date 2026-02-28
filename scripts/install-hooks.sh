#!/usr/bin/env bash
# Instala os git hooks locais do projeto via symlink.
# Execute uma vez após clonar: bash scripts/install-hooks.sh
# Ou via Makefile: make hooks
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS_SRC="$REPO_DIR/scripts/hooks"
HOOKS_DST="$REPO_DIR/.git/hooks"

GREEN='\033[0;32m'
RESET='\033[0m'

for hook in "$HOOKS_SRC"/*; do
    name="$(basename "$hook")"
    target="$HOOKS_DST/$name"

    chmod +x "$hook"
    ln -sf "../../scripts/hooks/$name" "$target"
    printf "${GREEN}✓${RESET} Hook instalado: .git/hooks/%s\n" "$name"
done

echo ""
echo "Hooks ativos. Serão executados automaticamente a cada commit."
