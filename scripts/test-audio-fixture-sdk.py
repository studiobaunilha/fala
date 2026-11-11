#!/usr/bin/env python3
"""Validate actual async AAC test helpers without building Fala or touching capture devices."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
developer = os.environ.get("DEVELOPER_DIR", "/Applications/Xcode.app/Contents/Developer")
env = {**os.environ, "DEVELOPER_DIR": developer}
env.pop("SDKROOT", None)
frameworks = str(Path(developer) / "Platforms/MacOSX.platform/Developer/Library/Frameworks")
private_frameworks = str(Path(developer) / "Platforms/MacOSX.platform/Developer/Library/PrivateFrameworks")
sdk = subprocess.check_output(["xcrun", "--sdk", "macosx", "--show-sdk-path"], env=env, text=True).strip()
includes = str(Path(developer) / "Platforms/MacOSX.platform/Developer/usr/lib")
with tempfile.TemporaryDirectory(prefix="fala-export-sdk-") as directory:
    temporary = Path(directory)
    flags = ["xcrun", "swiftc", "-swift-version", "6", "-warnings-as-errors", "-target",
             "arm64-apple-macosx27.2.1", "-sdk", sdk, "-I", includes, "-L", includes,
             "-F", frameworks, "-F", private_frameworks,
             "-module-cache-path", str(temporary / "module-cache")]
    helper = ROOT / "Tests/FalaTests/AudioTestFixtures.swift"
    subprocess.run(flags + ["-typecheck", str(helper)], env=env, check=True)
    print("Real audio fixture helper typecheck PASS", flush=True)
    executable = temporary / "audio-export-fixture"
    subprocess.run(flags + ["-parse-as-library", str(helper),
                           str(ROOT / "Tests/Fixtures/AudioExportSDKSmoke.swift"),
                           "-Xlinker", "-rpath", "-Xlinker", frameworks,
                           "-Xlinker", "-rpath", "-Xlinker", includes, "-o", str(executable)],
                   env=env, check=True)
    subprocess.run([str(executable)], env=env, check=True, timeout=30)
