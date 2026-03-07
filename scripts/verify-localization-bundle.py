#!/usr/bin/env python3
import json
import subprocess
import sys
from pathlib import Path


SUPPORTED_LANGUAGES = ("en", "es")


def load_catalog(catalog_path: Path) -> dict:
    raw = json.loads(catalog_path.read_text(encoding="utf-8"))
    return raw["strings"]


def load_compiled_strings(strings_path: Path) -> dict:
    result = subprocess.run(
        ["plutil", "-convert", "json", "-o", "-", str(strings_path)],
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(result.stdout)


def expected_translations(catalog: dict, language: str) -> dict:
    expected = {}
    for source, entry in catalog.items():
        localizations = entry.get("localizations", {})
        localized = localizations.get(language, {})
        string_unit = localized.get("stringUnit", {})
        value = string_unit.get("value")
        if value:
            expected[source] = value
    return expected


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: verify-localization-bundle.py <xcstrings> <bundle>", file=sys.stderr)
        return 1

    catalog_path = Path(sys.argv[1]).expanduser().resolve()
    bundle_path = Path(sys.argv[2]).expanduser().resolve()

    if not catalog_path.is_file():
        print(f"error: catálogo não encontrado: {catalog_path}", file=sys.stderr)
        return 1

    if not bundle_path.is_dir():
        print(f"error: bundle não encontrado: {bundle_path}", file=sys.stderr)
        return 1

    catalog = load_catalog(catalog_path)
    failures = []

    for language in SUPPORTED_LANGUAGES:
        strings_path = bundle_path / "Contents" / "Resources" / f"{language}.lproj" / "Localizable.strings"
        if not strings_path.is_file():
            failures.append(f"{language}: arquivo ausente em {strings_path}")
            continue

        compiled = load_compiled_strings(strings_path)
        expected = expected_translations(catalog, language)

        for source, translated in expected.items():
            compiled_value = compiled.get(source)
            if compiled_value != translated:
                failures.append(
                    f"{language}: chave '{source}' esperava {translated!r}, recebeu {compiled_value!r}"
                )

    if failures:
        print("error: bundle de localização desatualizado ou inconsistente:", file=sys.stderr)
        for failure in failures[:50]:
            print(f"  - {failure}", file=sys.stderr)
        if len(failures) > 50:
            print(f"  ... e mais {len(failures) - 50} divergências", file=sys.stderr)
        return 1

    print(f"✓ bundle de localização validado: {bundle_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
