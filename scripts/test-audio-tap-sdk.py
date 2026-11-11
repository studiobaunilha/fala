#!/usr/bin/env python3
"""Typecheck the real capture source and exercise SDK27 taps without microphone capture."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
env = {**os.environ, "DEVELOPER_DIR": os.environ.get("DEVELOPER_DIR", "/Applications/Xcode.app/Contents/Developer")}
with tempfile.TemporaryDirectory(prefix="fala-audio-tap-sdk27-") as directory:
    temporary = Path(directory)
    shim = temporary / "LocalizationShim.swift"
    shim.write_text("func L10n(_ key: String) -> String { key }\n")
    flags = ["xcrun", "swiftc", "-swift-version", "6", "-warnings-as-errors", "-target",
             "arm64-apple-macosx27.2.1", "-module-cache-path", str(temporary / "module-cache")]
    subprocess.run(flags + ["-typecheck", str(ROOT / "Sources/FalaCore/Core/AudioEngine.swift"),
                           str(ROOT / "Sources/FalaCore/Protocols/AudioRecording.swift"),
                           str(ROOT / "Sources/FalaCore/Core/Errors.swift"), str(shim)],
                   env=env, check=True)
    print("Real AudioEngine + protocol + errors typecheck PASS (Swift6, warnings-as-errors)", flush=True)
    fixture = ROOT / "Tests/Fixtures/AudioTapSDKSmoke.swift"
    executable = temporary / "audio-tap-offline"
    subprocess.run(flags + ["-parse-as-library", str(fixture), "-o", str(executable)], env=env, check=True)
    for channels in (1, 2):
        subprocess.run([str(executable), str(temporary / f"tap-{channels}.wav"), str(channels)],
                       env=env, check=True, timeout=20)
