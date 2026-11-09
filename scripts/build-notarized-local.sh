#!/usr/bin/env bash
# scripts/build-notarized-local.sh — Build, sign, notarize, and staple Fala locally for testing.
#
# Usage:
#   scripts/build-notarized-local.sh
#
# Não bumpa versão, não commita, não faz upload. Só gera um .dmg notarizado em /tmp
# pronto pra instalar localmente.
#
# Requisitos (ver scripts/release.sh):
#   - Xcode.app instalado
#   - Identidade "Developer ID Application" no Keychain
#   - Keychain profile `Fala Notarization` (ou FALA_NOTARY_PROFILE) configurado via `xcrun notarytool store-credentials`

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XCODE="$(bash "$REPO_DIR/scripts/xcode-dir.sh")"
PLIST="Sources/Fala/Resources/Info.plist"
NOTARY_PROFILE="${FALA_NOTARY_PROFILE:-Fala Notarization}"
APP_NAME="Fala"
TMP_DIR=$(mktemp -d)

BOLD='\033[1m'
GREEN='\033[32m'
CYAN='\033[36m'
GREY='\033[2m'
RED='\033[31m'
YELLOW='\033[33m'
RESET='\033[0m'

info() { printf "${CYAN}▶ %s${RESET}\n" "$1"; }
ok()   { printf "${GREEN}✓ %s${RESET}\n" "$1"; }
fail() { printf "${RED}✘ %s${RESET}\n" "$1"; exit 1; }

cleanup() {
    rm -rf "$TMP_DIR"
}

trap cleanup EXIT

# ── Preflight ─────────────────────────────────────────────────────────────────
info "Verificando pré-requisitos…"

if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" &>/dev/null; then
    fail "Keychain profile '$NOTARY_PROFILE' não encontrado."
fi

if ! security find-identity -v -p codesigning | grep -q "Developer ID Application:"; then
    fail "Identidade 'Developer ID Application' ausente no Keychain."
fi

ok "Pré-requisitos OK"

# ── Versão atual (só pra nomear o DMG — não bumpa) ───────────────────────────
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST")
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST")
GIT_SHORT=$(git -C "$REPO_DIR" rev-parse --short HEAD 2>/dev/null || echo "nogit")
TS=$(date +%Y%m%d-%H%M%S)
DMG_NAME="${APP_NAME}-${VERSION}-local-${GIT_SHORT}-${TS}.dmg"

printf "${CYAN}▶ Versão atual: ${BOLD}%s (build %s)${RESET} ${GREY}— gerando %s${RESET}\n" \
    "$VERSION" "$BUILD" "$DMG_NAME"

# ── 1. Build release ───────────────────────────────────────────────────────────
info "Compilando release…"
APP_DIR="$TMP_DIR/${APP_NAME}.app"
DEVELOPER_DIR="$XCODE" bash "$REPO_DIR/scripts/build-app.sh" release --app-dir "$APP_DIR"
ok "App bundle criado"

# ── 2. Verifica assinatura do app ─────────────────────────────────────────────
info "Verificando assinatura do app…"
codesign --verify --deep --strict "$APP_DIR" 2>&1 || fail "Assinatura do app inválida"
ok "Assinatura do app verificada"

# ── 3. Cria DMG ───────────────────────────────────────────────────────────────
info "Criando DMG…"
DMG_PATH="$TMP_DIR/$DMG_NAME"
DMG_STAGE_DIR="$TMP_DIR/dmg-stage"
rm -rf "$DMG_STAGE_DIR"
mkdir -p "$DMG_STAGE_DIR"
ditto "$APP_DIR" "$DMG_STAGE_DIR/${APP_NAME}.app"
ln -s /Applications "$DMG_STAGE_DIR/Applications"
bash "$REPO_DIR/scripts/create-dmg.sh" "$APP_NAME" "$DMG_STAGE_DIR" "$DMG_PATH"
ok "DMG: $DMG_NAME"

# ── 4. Assina DMG ─────────────────────────────────────────────────────────────
info "Assinando DMG…"
CODESIGN_IDENTITY="$(bash "$REPO_DIR/scripts/codesign-identity.sh" release)"
codesign --force --timestamp --sign "$CODESIGN_IDENTITY" "$DMG_PATH"
ok "DMG assinado"

# ── 5. Notariza ───────────────────────────────────────────────────────────────
info "Notarizando (pode levar 1-5 min)…"
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
ok "Ticket aprovado"

# ── 6. Grampeia ticket ────────────────────────────────────────────────────────
info "Grampeando ticket ao DMG…"
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH" || fail "Validação do staple falhou"
ok "Staple validado"

# ── 7. Move pro ~/Downloads e abre Finder ────────────────────────────────────
FINAL_DMG="$HOME/Downloads/$DMG_NAME"
mv "$DMG_PATH" "$FINAL_DMG"

printf "\n${GREEN}${BOLD}════════════════════════════════════════${RESET}\n"
printf "${GREEN}${BOLD}  ✓ DMG notarizado pronto${RESET}\n"
printf "${GREEN}${BOLD}════════════════════════════════════════${RESET}\n"
printf "  ${GREY}%s${RESET}\n" "$FINAL_DMG"

open -R "$FINAL_DMG"
