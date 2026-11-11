#!/usr/bin/env python3
"""Check the future-build OS contract without building Fala or invoking release actions."""
import json
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
EXPECTED = "27.2.1"


class PlatformPolicyTests(unittest.TestCase):
    def test_package_and_app_require_the_selected_baseline(self):
        manifest = json.loads(subprocess.check_output(
            ["bash", "scripts/swift-env.sh", "package", "dump-package"], cwd=ROOT, text=True
        ))
        macos = next(p for p in manifest["platforms"] if p["platformName"] == "macos")
        self.assertEqual(macos["version"], EXPECTED)
        with (ROOT / "Sources/Fala/Resources/Info.plist").open("rb") as handle:
            self.assertEqual(plistlib.load(handle)["LSMinimumSystemVersion"], EXPECTED)

    def test_future_feed_uses_app_minimum(self):
        source = (ROOT / "scripts/release.sh").read_text()
        start = source.index('cat > "$APPCAST_PATH" <<EOF')
        end = source.index("\nEOF", start) + len("\nEOF")
        # Execute only the metadata binding and XML heredoc, never the release program.
        binding = next((line for line in source.splitlines()
                        if line.startswith("MIN_MACOS_VERSION=")), "")
        self.assertTrue(binding, "Feed generation must read the application's OS minimum")
        with tempfile.TemporaryDirectory(prefix="fala-platform-feed-") as directory:
            output = Path(directory) / "appcast.xml"
            env = {"REPO_DIR": str(ROOT), "PLIST": "Sources/Fala/Resources/Info.plist",
                   "APPCAST_PATH": str(output), "R2_URL": "https://example.invalid",
                   "BUILD": "999", "VERSION": "test", "PUB_DATE": "test",
                   "DMG_NAME": "test.dmg", "ED_SIGNATURE": "test", "LENGTH": "1"}
            import os
            subprocess.run(["bash", "-eu", "-c", binding + "\n" + source[start:end]],
                           env={**os.environ, **env}, check=True)
            minimum = ET.parse(output).find(
                "./channel/item/{http://www.andymatuschak.org/xml-namespaces/sparkle}minimumSystemVersion"
            )
            self.assertEqual(minimum.text, EXPECTED)

    def test_staged_bundle_rejects_a_binary_below_app_minimum(self):
        source = (ROOT / "scripts/build-app.sh").read_text()
        helpers = source[source.index("assert_staged_path_exists() {"):source.index("stage_bundle() {")]
        import os
        with tempfile.TemporaryDirectory(prefix="fala-platform-stage-") as directory:
            app = Path(directory) / "Fala.app"
            products = Path(directory) / "products"
            products.mkdir()
            for relative in ["Contents/MacOS/Fala", "Contents/Info.plist",
                             "Contents/Resources/AppIcon.icns",
                             "Contents/Resources/Fala_FalaCore.bundle",
                             "Contents/Resources/mlx-swift_Cmlx.bundle/Contents/Resources/default.metallib",
                             "Contents/Frameworks/Sparkle.framework"]:
                path = app / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.touch()
            c = Path(directory) / "main.c"
            c.write_text("int main(void) { return 0; }\n")
            binary = app / "Contents/MacOS/Fala"
            env = {**os.environ, "APP": str(app), "BUNDLE_BINARY": str(binary),
                   "PRODUCTS_DIR": str(products), "MIN_MACOS_VERSION": EXPECTED}
            for minimum, expected_status in [("14.0", 1), (EXPECTED, 0)]:
                subprocess.run(["xcrun", "clang", "-target", "arm64-apple-macosx" + minimum,
                                str(c), "-o", str(binary)], check=True)
                result = subprocess.run(["bash", "-eu", "-c", helpers + "\nverify_staged_bundle_contents"],
                                        env=env, capture_output=True, text=True)
                self.assertEqual(result.returncode, expected_status, result.stderr)
                if expected_status:
                    self.assertIn("difere do app", result.stderr)

    def test_staging_checks_minimum_before_signing(self):
        source = (ROOT / "scripts/build-app.sh").read_text()
        staging = source[source.index("assert_staged_path_exists() {"):source.index("\nbuild_with_xcode\n")]
        import os
        with tempfile.TemporaryDirectory(prefix="fala-platform-sign-order-") as directory:
            temporary = Path(directory)
            app = temporary / "Fala.app"
            products = temporary / "products"
            for relative in ["Fala_FalaCore.bundle", "Sparkle.framework",
                             "mlx-swift_Cmlx.bundle/Contents/Resources"]:
                (products / relative).mkdir(parents=True, exist_ok=True)
            (products / "mlx-swift_Cmlx.bundle/Contents/Resources/default.metallib").touch()
            c = temporary / "main.c"
            c.write_text("int main(void) { return 0; }\n")
            binary = temporary / "Fala"
            log = temporary / "codesign-calls.log"
            env = {**os.environ, "APP": str(app), "BUNDLE_BINARY": str(app / "Contents/MacOS/Fala"),
                   "BINARY_SOURCE": str(binary), "PRODUCTS_DIR": str(products),
                   "MIN_MACOS_VERSION": EXPECTED, "REPO_DIR": str(ROOT),
                   "CODESIGN_IDENTITY": "fixture-no-key", "FAKE_CODESIGN_LOG": str(log)}
            substitutes = 'codesign() { printf "%s\\n" "$*" >> "$FAKE_CODESIGN_LOG"; }\n'
            substitutes += 'install_name_tool() { :; }\n'
            for minimum, expected_status in [("14.0", 1), (EXPECTED, 0)]:
                log.unlink(missing_ok=True)
                subprocess.run(["xcrun", "clang", "-target", "arm64-apple-macosx" + minimum,
                                str(c), "-o", str(binary)], check=True)
                result = subprocess.run(["bash", "-eu", "-c", substitutes + staging + "\nstage_bundle"],
                                        env=env, capture_output=True, text=True)
                self.assertEqual(result.returncode, expected_status, result.stderr)
                if expected_status:
                    self.assertFalse(log.exists(), "Invalid binary reached codesign")
                else:
                    self.assertTrue(log.exists(), "Valid binary did not reach codesign")
                    self.assertIn(str(app), log.read_text())

    def test_toolchain_retains_patch_minimum_in_macho(self):
        with tempfile.TemporaryDirectory(prefix="fala-platform-macho-") as directory:
            source = Path(directory) / "main.c"
            binary = Path(directory) / "platform-probe"
            source.write_text("int main(void) { return 0; }\n")
            subprocess.run(["xcrun", "clang", "-Werror", "-target",
                            "arm64-apple-macosx" + EXPECTED, str(source), "-o", str(binary)], check=True)
            metadata = subprocess.check_output(["xcrun", "vtool", "-show-build", str(binary)], text=True)
            self.assertEqual(re.search(r"minos\s+(\S+)", metadata).group(1), EXPECTED)
            subprocess.run([str(binary)], check=True)


if __name__ == "__main__":
    unittest.main(verbosity=2)
