#!/usr/bin/env bash
# scripts/release.sh — Build, sign, package, and publish a Fala release via Sparkle + Cloudflare R2.
#
# Usage:
#   scripts/release.sh [--dry-run]
#
# Requirements:
#   - wrangler CLI (authenticated)
#   - Sparkle EdDSA private key at ~/Library/Sparkle/eddsa_key (generate_keys)
#
# The script will:
#   1. Read version from Info.plist
#   2. Build a release binary
#   3. Create a signed .dmg
#   4. Generate EdDSA signature
#   5. Update appcast.xml
#   6. Upload .dmg + appcast.xml to R2

set -euo pipefail

# ── Config ─────────────────────────────────────────────────────────────────────
XCODE="/Applications/Xcode.app/Contents/Developer"
SWIFT="DEVELOPER_DIR=$XCODE swift"
SPARKLE_BIN=".build/artifacts/sparkle/Sparkle/bin"
BUCKET="fala-updates"
R2_URL="https://pub-e4238720a12f45f68eff0a79f3dda647.r2.dev"
PLIST="Sources/Fala/Resources/Info.plist"
APP_NAME="Fala"
TMP_DIR=$(mktemp -d)
DRY_RUN=false

# Colors
BOLD='\033[1m'
GREEN='\033[32m'
CYAN='\033[36m'
GREY='\033[2m'
RED='\033[31m'
RESET='\033[0m'

if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    printf "${CYAN}▶ Dry-run mode — nothing will be uploaded${RESET}\n"
fi

# ── Helpers ────────────────────────────────────────────────────────────────────
info()  { printf "${CYAN}▶ %s${RESET}\n" "$1"; }
ok()    { printf "${GREEN}✓ %s${RESET}\n" "$1"; }
fail()  { printf "${RED}✘ %s${RESET}\n" "$1"; exit 1; }

# ── 1. Read version ───────────────────────────────────────────────────────────
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST")
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST")
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
info "Version: ${VERSION} (build ${BUILD})"

# ── 2. Build release ──────────────────────────────────────────────────────────
info "Building release…"
eval "$SWIFT build -c release" 2>&1 | tail -3

# ── 3. Create .app bundle ─────────────────────────────────────────────────────
info "Creating app bundle…"
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

ok "App bundle created"

# ── 4. Create DMG ──────────────────────────────────────────────────────────────
info "Creating DMG…"
DMG_PATH="$TMP_DIR/$DMG_NAME"
hdiutil create -volname "$APP_NAME" -srcfolder "$APP_DIR" -ov -format UDZO "$DMG_PATH" 2>&1 | tail -1
ok "DMG: $DMG_PATH"

# ── 5. Sign with Sparkle EdDSA ─────────────────────────────────────────────────
info "Signing with EdDSA…"
SIGNATURE=$("$SPARKLE_BIN/sign_update" "$DMG_PATH" 2>&1)
# sign_update outputs: sparkle:edSignature="..." length="..."
ED_SIGNATURE=$(echo "$SIGNATURE" | grep -o 'sparkle:edSignature="[^"]*"' | cut -d'"' -f2)
LENGTH=$(echo "$SIGNATURE" | grep -o 'length="[^"]*"' | cut -d'"' -f2)

if [[ -z "$ED_SIGNATURE" ]]; then
    fail "Failed to generate EdDSA signature. Run: $SPARKLE_BIN/generate_keys"
fi
ok "Signature: ${ED_SIGNATURE:0:20}…"

# ── 6. Generate appcast.xml ───────────────────────────────────────────────────
info "Generating appcast.xml…"
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
ok "appcast.xml generated"

# ── 7. Upload to R2 ───────────────────────────────────────────────────────────
if $DRY_RUN; then
    info "[dry-run] Would upload:"
    printf "  ${GREY}%s → %s/%s${RESET}\n" "$DMG_PATH" "$BUCKET" "$DMG_NAME"
    printf "  ${GREY}%s → %s/appcast.xml${RESET}\n" "$APPCAST_PATH" "$BUCKET"
    printf "\n${GREY}appcast.xml contents:${RESET}\n"
    cat "$APPCAST_PATH"
else
    info "Uploading $DMG_NAME to R2…"
    wrangler r2 object put "${BUCKET}/${DMG_NAME}" --file "$DMG_PATH" --content-type "application/octet-stream" --remote
    ok "DMG uploaded"

    info "Uploading appcast.xml to R2…"
    wrangler r2 object put "${BUCKET}/appcast.xml" --file "$APPCAST_PATH" --content-type "application/xml" --remote
    ok "appcast.xml uploaded"

    printf "\n${GREEN}${BOLD}✓ Release ${VERSION} published!${RESET}\n"
    printf "  ${GREY}Feed: ${R2_URL}/appcast.xml${RESET}\n"
    printf "  ${GREY}DMG:  ${R2_URL}/${DMG_NAME}${RESET}\n"
fi

# ── Cleanup ────────────────────────────────────────────────────────────────────
rm -rf "$TMP_DIR"
