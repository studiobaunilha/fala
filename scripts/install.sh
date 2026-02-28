#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BINARY_NAME="Sussurro"
BUNDLE_DIR="$HOME/Applications/Sussurro.app"
BUNDLE_BINARY="$BUNDLE_DIR/Contents/MacOS/$BINARY_NAME"
LAUNCHER="$HOME/bin/sussurro"

# ── 1. Build ──────────────────────────────────────────────────────────────────
echo "▶ Building Sussurro (release)…"
cd "$REPO_DIR"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build -c release

BINARY="$REPO_DIR/.build/release/$BINARY_NAME"

# ── 2. Create .app bundle ─────────────────────────────────────────────────────
# macOS ties TCC permissions (Microphone, Accessibility) to the bundle identifier.
# Without a bundle the OS attributes permissions to Terminal.app instead.
echo "▶ Creating app bundle → $BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/Contents/MacOS"
cp "$BINARY" "$BUNDLE_BINARY"
cp "$REPO_DIR/Sources/Sussurro/Resources/Info.plist" "$BUNDLE_DIR/Contents/Info.plist"

# ── 3. Launcher script ────────────────────────────────────────────────────────
# Routes 'sussurro' (menu bar) and 'sussurro transcribe …' (CLI) correctly.
mkdir -p "$HOME/bin"
cat > "$LAUNCHER" << 'EOF'
#!/usr/bin/env bash
if [ "${1-}" = "transcribe" ] || [ "${1-}" = "--help" ] || [ "${1-}" = "-h" ]; then
    # CLI batch mode: run the binary directly (no Accessibility needed)
    exec "$HOME/Applications/Sussurro.app/Contents/MacOS/Sussurro" "$@"
else
    # Menu bar mode: launch as a proper .app so TCC permissions are correct
    open "$HOME/Applications/Sussurro.app"
fi
EOF
chmod +x "$LAUNCHER"

# ── 4. Summary ────────────────────────────────────────────────────────────────
echo ""
echo "✓ Done."
echo ""
echo "  sussurro                           → starts menu bar app"
echo "  sussurro transcribe <file>         → transcribes audio file"
echo "  sussurro --help                    → usage"
echo ""
echo "FIRST LAUNCH — run once to register permissions:"
echo "  open ~/Applications/Sussurro.app"
echo ""
echo "macOS will prompt for:"
echo "  • Microphone    → allow"
echo "  • Accessibility → allow  (opens System Settings, enable the toggle)"
echo ""
echo "After granting, quit and relaunch. From then on just run: sussurro"
