#!/usr/bin/env bash
# scripts/release.sh — Build, sign, package, and publish a Fala release via Sparkle + Cloudflare R2.
#
# Usage:
#   scripts/release.sh patch          Bump 1.0 → 1.0.1  (bug fix)
#   scripts/release.sh minor          Bump 1.0 → 1.1    (new feature)
#   scripts/release.sh major          Bump 1.0 → 2.0    (breaking change)
#   scripts/release.sh patch --dry-run   Test without uploading
#
# The script will:
#   1. Auto-bump version + build in Info.plist
#   2. Commit + tag
#   3. Build a release binary
#   4. Create a signed .dmg
#   5. Generate EdDSA signature
#   6. Update appcast.xml
#   7. Upload .dmg + appcast.xml to R2

set -euo pipefail

# ── Config ─────────────────────────────────────────────────────────────────────
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XCODE="$(bash "$REPO_DIR/scripts/xcode-dir.sh")"
SPARKLE_BIN=".build/artifacts/sparkle/Sparkle/bin"
BUCKET="fala-updates"
R2_URL="https://pub-e4238720a12f45f68eff0a79f3dda647.r2.dev"
PLIST="Sources/Fala/Resources/Info.plist"
MIN_MACOS_VERSION=$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" "$REPO_DIR/$PLIST")
APP_NAME="Fala"
TMP_DIR=$(mktemp -d)
DRY_RUN=false
BUMP="${1:-}"
NOTARY_PROFILE="${FALA_NOTARY_PROFILE:-Fala Notarization}"

# Colors
BOLD='\033[1m'
GREEN='\033[32m'
CYAN='\033[36m'
GREY='\033[2m'
RED='\033[31m'
YELLOW='\033[33m'
RESET='\033[0m'

# ── Validate args ──────────────────────────────────────────────────────────────
if [[ -z "$BUMP" ]] || [[ ! "$BUMP" =~ ^(patch|minor|major)$ ]]; then
    printf "${RED}Uso: scripts/release.sh <patch|minor|major> [--dry-run]${RESET}\n"
    printf "\n"
    printf "  ${CYAN}patch${RESET}   1.0 → 1.0.1  (correção de bug)\n"
    printf "  ${CYAN}minor${RESET}   1.0 → 1.1    (nova funcionalidade)\n"
    printf "  ${CYAN}major${RESET}   1.0 → 2.0    (mudança grande)\n"
    exit 1
fi

if [[ "${2:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    printf "${YELLOW}▶ Dry-run mode — nada será publicado${RESET}\n"
fi

# ── Helpers ────────────────────────────────────────────────────────────────────
info()  { printf "${CYAN}▶ %s${RESET}\n" "$1"; }
ok()    { printf "${GREEN}✓ %s${RESET}\n" "$1"; }
fail()  { printf "${RED}✘ %s${RESET}\n" "$1"; exit 1; }

cleanup() {
    rm -rf "$TMP_DIR"
}

trap cleanup EXIT

# ── Preflight checks ──────────────────────────────────────────────────────────
info "Verificando pré-requisitos…"

# Dirty working tree?
if [[ -n "$(git status --porcelain)" ]]; then
    fail "Working tree tem alterações não commitadas. Commit ou stash primeiro."
fi

# Check access to the existing key without generating a replacement.
printf 'Fala signing preflight\n' > "$TMP_DIR/signing-preflight.txt"
if ! "$SPARKLE_BIN/sign_update" -p "$TMP_DIR/signing-preflight.txt" >/dev/null 2>&1; then
    fail "Chave EdDSA original não encontrada ou inacessível. Recupere a chave existente antes de publicar; não gere uma substituta."
fi

# wrangler?
if ! command -v wrangler &>/dev/null; then
    fail "wrangler não encontrado. Execute: npm install -g wrangler"
fi

# Notarization keychain profile? (only needed for real releases)
if ! $DRY_RUN; then
    if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" &>/dev/null; then
        fail "Keychain profile '$NOTARY_PROFILE' não encontrado ou inválido."
    fi
fi

ok "Pré-requisitos OK"

# ── 1. Bump version ───────────────────────────────────────────────────────────
OLD_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST")
OLD_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST")

# Parse semver
IFS='.' read -r V_MAJOR V_MINOR V_PATCH <<< "$OLD_VERSION"
V_PATCH="${V_PATCH:-0}"

case "$BUMP" in
    major) V_MAJOR=$((V_MAJOR + 1)); V_MINOR=0; V_PATCH=0 ;;
    minor) V_MINOR=$((V_MINOR + 1)); V_PATCH=0 ;;
    patch) V_PATCH=$((V_PATCH + 1)) ;;
esac

VERSION="${V_MAJOR}.${V_MINOR}"
if [[ "$V_PATCH" -gt 0 ]]; then
    VERSION="${VERSION}.${V_PATCH}"
fi
BUILD=$((OLD_BUILD + 1))

printf "${CYAN}▶ Versão: ${GREY}%s (build %s)${CYAN} → ${BOLD}%s (build %s)${RESET}\n" \
    "$OLD_VERSION" "$OLD_BUILD" "$VERSION" "$BUILD"

# Write to Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$PLIST"

DMG_NAME="${APP_NAME}-${VERSION}.dmg"

# ── 2. Commit + tag ───────────────────────────────────────────────────────────
info "Commitando versão ${VERSION}…"
git add "$PLIST"
git commit -m "chore: bump version to ${VERSION} (build ${BUILD})"
git tag "v${VERSION}"
ok "Commit + tag v${VERSION}"

# ── 3. Build release ──────────────────────────────────────────────────────────
info "Compilando release…"
APP_DIR="$TMP_DIR/${APP_NAME}.app"
DEVELOPER_DIR="$XCODE" bash "$REPO_DIR/scripts/build-app.sh" release --app-dir "$APP_DIR"
ok "App bundle criado"

# ── 3.5. Verify app bundle signature ─────────────────────────────────────────
info "Verificando assinatura do app bundle…"
codesign --verify --deep --strict "$APP_DIR" 2>&1 || fail "Assinatura do app bundle inválida"
ok "Assinatura do app bundle verificada"

# ── 4. Create DMG ──────────────────────────────────────────────────────────────
info "Criando DMG…"
DMG_PATH="$TMP_DIR/$DMG_NAME"
DMG_STAGE_DIR="$TMP_DIR/dmg-stage"
rm -rf "$DMG_STAGE_DIR"
mkdir -p "$DMG_STAGE_DIR"
ditto "$APP_DIR" "$DMG_STAGE_DIR/${APP_NAME}.app"
ln -s /Applications "$DMG_STAGE_DIR/Applications"
bash "$REPO_DIR/scripts/create-dmg.sh" "$APP_NAME" "$DMG_STAGE_DIR" "$DMG_PATH"
ok "DMG: $DMG_NAME"

# ── 4.1. Codesign DMG ────────────────────────────────────────────────────────
info "Assinando DMG…"
CODESIGN_IDENTITY="$(bash "$REPO_DIR/scripts/codesign-identity.sh" release)"
codesign --force --timestamp --sign "$CODESIGN_IDENTITY" "$DMG_PATH"
ok "DMG assinado"

# ── 4.5. Notarize App ──────────────────────────────────────────────────────────
# Notarization requires an app-specific password stored in the keychain (e.g., as 'fala-notary').
if ! $DRY_RUN; then
    info "Notarizando $APP_NAME..."
    xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
    ok "Ticket de notarização aprovado"

    info "Grampeando (stapling) o ticket ao DMG…"
    xcrun stapler staple "$DMG_PATH"
    ok "Ticket grampeado ao DMG"

    info "Validando ticket grampeado…"
    xcrun stapler validate "$DMG_PATH" || fail "Validação do staple falhou"
    ok "Staple validado com sucesso"
else
    info "[dry-run] Ignorando notarização via notarytool."
fi

# ── 5. Sign with Sparkle EdDSA ─────────────────────────────────────────────────
info "Assinando com EdDSA…"
SIGNATURE=$("$SPARKLE_BIN/sign_update" "$DMG_PATH" 2>&1)
ED_SIGNATURE=$(echo "$SIGNATURE" | grep -o 'sparkle:edSignature="[^"]*"' | cut -d'"' -f2)
LENGTH=$(echo "$SIGNATURE" | grep -o 'length="[^"]*"' | cut -d'"' -f2)

if [[ -z "$ED_SIGNATURE" ]]; then
    fail "Falha ao gerar assinatura EdDSA."
fi
ok "Assinatura: ${ED_SIGNATURE:0:20}…"

# ── 6. Generate appcast.xml ───────────────────────────────────────────────────
info "Gerando appcast.xml…"
APPCAST_PATH="$TMP_DIR/appcast.xml"
PUB_DATE=$(date -u +"%a, %d %b %Y %H:%M:%S %z")

cat > "$APPCAST_PATH" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>Fala Updates</title>
    <link>${R2_URL}/appcast.xml</link>
    <description>Atualizações do Fala</description>
    <language>pt-BR</language>
    <item>
      <title>Versão ${VERSION}</title>
      <pubDate>${PUB_DATE}</pubDate>
      <sparkle:version>${BUILD}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>${MIN_MACOS_VERSION}</sparkle:minimumSystemVersion>
      <enclosure
        url="${R2_URL}/${DMG_NAME}"
        sparkle:edSignature="${ED_SIGNATURE}"
        length="${LENGTH}"
        type="application/octet-stream"
      />
    </item>
  </channel>
</rss>
EOF
ok "appcast.xml gerado"

# ── 7. Upload to R2 ───────────────────────────────────────────────────────────
if $DRY_RUN; then
    info "[dry-run] Upload simulado:"
    printf "  ${GREY}%s → %s/%s${RESET}\n" "$DMG_NAME" "$BUCKET" "$DMG_NAME"
    printf "  ${GREY}appcast.xml → %s/appcast.xml${RESET}\n" "$BUCKET"
    printf "\n${GREY}appcast.xml:${RESET}\n"
    cat "$APPCAST_PATH"
    printf "\n${YELLOW}⚠ Dry-run: revertendo commit e tag…${RESET}\n"
    git tag -d "v${VERSION}" 2>/dev/null
    git reset --soft HEAD~1
    git checkout "$PLIST"
    ok "Revertido — nenhuma alteração permanente"
else
    info "Fazendo upload de $DMG_NAME..."
    wrangler r2 object put "${BUCKET}/${DMG_NAME}" --file "$DMG_PATH" --content-type "application/octet-stream" --remote
    ok "DMG enviado"

    info "Fazendo upload de Fala-latest.dmg…"
    wrangler r2 object put "${BUCKET}/Fala-latest.dmg" --file "$DMG_PATH" --content-type "application/octet-stream" --remote
    ok "Fala-latest.dmg atualizado"

    info "Fazendo upload de appcast.xml…"
    wrangler r2 object put "${BUCKET}/appcast.xml" --file "$APPCAST_PATH" --content-type "application/xml" --remote
    ok "appcast.xml enviado"

    # Push commit + tag
    info "Fazendo push…"
    git push origin HEAD:refs/heads/main "refs/tags/v${VERSION}"

    printf "\n${GREEN}${BOLD}════════════════════════════════════════${RESET}\n"
    printf "${GREEN}${BOLD}  ✓ Fala v${VERSION} publicado!${RESET}\n"
    printf "${GREEN}${BOLD}════════════════════════════════════════${RESET}\n"
    printf "  ${GREY}Feed: ${R2_URL}/appcast.xml${RESET}\n"
    printf "  ${GREY}DMG:  ${R2_URL}/${DMG_NAME}${RESET}\n"
    printf "  ${GREY}Tag:  v${VERSION}${RESET}\n"
fi

# ── Cleanup ────────────────────────────────────────────────────────────────────
rm -rf "$TMP_DIR"
