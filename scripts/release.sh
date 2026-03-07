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
SWIFT="DEVELOPER_DIR=$XCODE swift"
SPARKLE_BIN=".build/artifacts/sparkle/Sparkle/bin"
BUCKET="fala-updates"
R2_URL="https://pub-e4238720a12f45f68eff0a79f3dda647.r2.dev"
PLIST="Sources/Fala/Resources/Info.plist"
APP_NAME="Fala"
TMP_DIR=$(mktemp -d)
DRY_RUN=false
BUMP="${1:-}"

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

# ── Preflight checks ──────────────────────────────────────────────────────────
info "Verificando pré-requisitos…"

# Dirty working tree?
if [[ -n "$(git status --porcelain)" ]]; then
    fail "Working tree tem alterações não commitadas. Commit ou stash primeiro."
fi

# Sparkle signing key?
if ! "$SPARKLE_BIN/generate_keys" 2>&1 | grep -q "pre-existing"; then
    fail "Chave EdDSA não encontrada. Execute: $SPARKLE_BIN/generate_keys"
fi

# wrangler?
if ! command -v wrangler &>/dev/null; then
    fail "wrangler não encontrado. Execute: npm install -g wrangler"
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
eval "$SWIFT build -c release" 2>&1 | tail -3

# ── 4. Create .app bundle ─────────────────────────────────────────────────────
info "Criando app bundle…"
APP_DIR="$TMP_DIR/${APP_NAME}.app"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"
mkdir -p "$APP_DIR/Contents/Frameworks"

cp .build/release/Fala "$APP_DIR/Contents/MacOS/"
cp Sources/Fala/Resources/AppIcon.icns "$APP_DIR/Contents/Resources/"
cp Sources/Fala/Resources/Info.plist "$APP_DIR/Contents/"
cp -R .build/release/Sparkle.framework "$APP_DIR/Contents/Frameworks/"
install_name_tool -add_rpath @executable_path/../Frameworks "$APP_DIR/Contents/MacOS/Fala" 2>/dev/null || true
codesign --force --deep --sign - "$APP_DIR"

ok "App bundle criado"

# ── 5. Create DMG ──────────────────────────────────────────────────────────────
info "Criando DMG…"
DMG_PATH="$TMP_DIR/$DMG_NAME"
hdiutil create -volname "$APP_NAME" -srcfolder "$APP_DIR" -ov -format UDZO "$DMG_PATH" 2>&1 | tail -1
ok "DMG: $DMG_NAME"

# ── 6. Sign with Sparkle EdDSA ─────────────────────────────────────────────────
info "Assinando com EdDSA…"
SIGNATURE=$("$SPARKLE_BIN/sign_update" "$DMG_PATH" 2>&1)
ED_SIGNATURE=$(echo "$SIGNATURE" | grep -o 'sparkle:edSignature="[^"]*"' | cut -d'"' -f2)
LENGTH=$(echo "$SIGNATURE" | grep -o 'length="[^"]*"' | cut -d'"' -f2)

if [[ -z "$ED_SIGNATURE" ]]; then
    fail "Falha ao gerar assinatura EdDSA."
fi
ok "Assinatura: ${ED_SIGNATURE:0:20}…"

# ── 7. Generate appcast.xml ───────────────────────────────────────────────────
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
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
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

# ── 8. Upload to R2 ───────────────────────────────────────────────────────────
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
    git push origin main --tags 2>/dev/null || printf "  ${GREY}(push falhou ou remote não configurado — faça manualmente)${RESET}\n"

    printf "\n${GREEN}${BOLD}════════════════════════════════════════${RESET}\n"
    printf "${GREEN}${BOLD}  ✓ Fala v${VERSION} publicado!${RESET}\n"
    printf "${GREEN}${BOLD}════════════════════════════════════════${RESET}\n"
    printf "  ${GREY}Feed: ${R2_URL}/appcast.xml${RESET}\n"
    printf "  ${GREY}DMG:  ${R2_URL}/${DMG_NAME}${RESET}\n"
    printf "  ${GREY}Tag:  v${VERSION}${RESET}\n"
fi

# ── Cleanup ────────────────────────────────────────────────────────────────────
rm -rf "$TMP_DIR"
