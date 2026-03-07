#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XCODE_DIR="$(bash "$REPO_DIR/scripts/xcode-dir.sh")"
BINARY_NAME="Fala"
BUNDLE_DIR="$HOME/Applications/Fala.app"
BUNDLE_BINARY="$BUNDLE_DIR/Contents/MacOS/$BINARY_NAME"
LAUNCHER="$HOME/bin/fala"

# ── 1. Build ──────────────────────────────────────────────────────────────────
echo "▶ Building Fala (release)…"
cd "$REPO_DIR"
DEVELOPER_DIR="$XCODE_DIR" swift build -c release

BINARY="$REPO_DIR/.build/release/$BINARY_NAME"

# ── 2. Create .app bundle ─────────────────────────────────────────────────────
# macOS ties TCC permissions (Microphone, Accessibility) to the bundle identifier.
# Without a bundle the OS attributes permissions to Terminal.app instead.
echo "▶ Creating app bundle → $BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/Contents/MacOS"
cp "$BINARY" "$BUNDLE_BINARY"
cp "$REPO_DIR/Sources/Fala/Resources/Info.plist" "$BUNDLE_DIR/Contents/Info.plist"

# ── 3. Launcher script ────────────────────────────────────────────────────────
# Routes 'fala' (menu bar) and 'fala transcribe …' (CLI) correctly.
mkdir -p "$HOME/bin"
cat > "$LAUNCHER" << 'EOF'
#!/usr/bin/env bash
if [ "${1-}" = "transcribe" ] || [ "${1-}" = "--help" ] || [ "${1-}" = "-h" ]; then
    # CLI batch mode: run the binary directly (no Accessibility needed)
    exec "$HOME/Applications/Fala.app/Contents/MacOS/Fala" "$@"
else
    # Menu bar mode: launch as a proper .app so TCC permissions are correct
    open "$HOME/Applications/Fala.app"
fi
EOF
chmod +x "$LAUNCHER"

# ── 4. Summary ────────────────────────────────────────────────────────────────
echo ""
echo "✓ Done."
echo ""
echo "  fala                           → starts menu bar app"
echo "  fala transcribe <file>         → transcribes audio file"
echo "  fala --help                    → usage"
echo ""
echo "FIRST LAUNCH — run once to register permissions:"
echo "  open ~/Applications/Fala.app"
echo ""
echo "macOS will prompt for:"
echo "  • Microphone    → allow"
echo "  • Accessibility → allow  (opens System Settings, enable the toggle)"
echo ""
echo "After granting, quit and relaunch. From then on just run: fala"
