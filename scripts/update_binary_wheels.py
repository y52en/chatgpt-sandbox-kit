#!/usr/bin/env python3
"""Refresh vendored Capstone/Keystone wheels from PyPI.

The target is CPython 3.13 on Linux x86_64. Only stable, non-yanked wheel
artifacts compatible with that target are considered. Wheels are verified
against the SHA-256 published by PyPI, then split into 1,000,000-byte chunks
so every tracked binary part remains strictly below 1 MiB (1,048,576 bytes).
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import tempfile
import urllib.request
import zipfile
from pathlib import Path

from packaging.specifiers import InvalidSpecifier, SpecifierSet
from packaging.tags import compatible_tags, cpython_tags
from packaging.utils import parse_wheel_filename
from packaging.version import InvalidVersion, Version

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "third_party" / "wheels"
CHUNK_SIZE = 1_000_000
PYTHON_VERSION = (3, 13)
PYTHON_VERSION_TEXT = "3.13"
INTERPRETER = "cp313"

PACKAGES = (
    {
        "project": "capstone",
        "display": "Capstone",
        "license_file": "CAPSTONE-LICENSE.txt",
    },
    {
        "project": "keystone-engine",
        "display": "Keystone Engine",
        "license_file": "KEYSTONE-LICENSE.txt",
    },
)


def target_tags() -> set:
    platforms = [f"manylinux_2_{minor}_x86_64" for minor in range(41, 4, -1)]
    platforms += [
        "manylinux2014_x86_64",
        "manylinux2010_x86_64",
        "manylinux1_x86_64",
        "linux_x86_64",
    ]
    tags = set(cpython_tags(python_version=PYTHON_VERSION, platforms=platforms))
    tags.update(
        compatible_tags(
            python_version=PYTHON_VERSION,
            interpreter=INTERPRETER,
            platforms=platforms,
        )
    )
    return tags


TARGET_TAGS = target_tags()


def fetch_json(url: str) -> dict:
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "chatgpt-sandbox-kit-wheel-updater/1"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def download(url: str, destination: Path) -> None:
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "chatgpt-sandbox-kit-wheel-updater/1"},
    )
    with urllib.request.urlopen(request, timeout=60) as response, destination.open("wb") as fh:
        shutil.copyfileobj(response, fh)


def wheel_tags_compatible(filename: str) -> bool:
    if not filename.endswith(".whl"):
        return False
    try:
        _name, _version, _build, tags = parse_wheel_filename(filename)
    except Exception:
        return False
    return bool(tags & TARGET_TAGS)


def requires_python_compatible(requires_python: str | None) -> bool:
    if not requires_python:
        return True
    try:
        return SpecifierSet(requires_python).contains(
            PYTHON_VERSION_TEXT,
            prereleases=True,
        )
    except InvalidSpecifier:
        return False


def pick_latest(project: str) -> tuple[str, dict]:
    metadata = fetch_json(f"https://pypi.org/pypi/{project}/json")
    candidates: list[tuple[Version, str, list[dict]]] = []

    for raw_version, files in metadata.get("releases", {}).items():
        try:
            version = Version(raw_version)
        except InvalidVersion:
            continue
        if version.is_prerelease or version.is_devrelease:
            continue

        matches = [
            item
            for item in files
            if not item.get("yanked", False)
            and item.get("packagetype") == "bdist_wheel"
            and wheel_tags_compatible(item.get("filename", ""))
            and requires_python_compatible(item.get("requires_python"))
        ]
        if matches:
            candidates.append((version, raw_version, matches))

    if not candidates:
        raise RuntimeError(
            f"no stable CPython {PYTHON_VERSION_TEXT} / Linux x86_64 wheel found for {project}"
        )

    _version, raw_version, matches = max(candidates, key=lambda item: item[0])
    selected = sorted(matches, key=lambda item: item["filename"])[0]
    return raw_version, selected


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def extract_license(wheel: Path) -> bytes:
    with zipfile.ZipFile(wheel) as archive:
        names = archive.namelist()
        preferred = [
            name
            for name in names
            if ".dist-info/" in name
            and Path(name).name.upper() in {"LICENSE", "LICENSE.TXT", "COPYING", "COPYING.TXT"}
        ]
        fallback = [
            name
            for name in names
            if ".dist-info/" in name
            and Path(name).name.upper().startswith(("LICENSE", "COPYING"))
        ]
        choices = preferred or fallback
        if not choices:
            raise RuntimeError(f"license notice not found inside {wheel.name}")
        return archive.read(sorted(choices)[0])


def split_file(source: Path, prefix: Path) -> list[Path]:
    parts: list[Path] = []
    with source.open("rb") as fh:
        index = 0
        while True:
            data = fh.read(CHUNK_SIZE)
            if not data:
                break
            part = Path(f"{prefix}.part{index:03d}")
            part.write_bytes(data)
            if part.stat().st_size >= 1024 * 1024:
                raise RuntimeError(f"part exceeds the strict <1 MiB limit: {part}")
            parts.append(part)
            index += 1
    return parts


def render_reassemble(filenames: list[str]) -> str:
    body = [
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        'cd -- "$(dirname -- "${BASH_SOURCE[0]}")"',
    ]
    for filename in filenames:
        body.append(f"cat {filename!r}.part* > {filename!r}")
    body += [
        "sha256sum --check --strict SHA256SUMS",
        "printf 'Reassembled and verified wheels.\\n'",
        "",
    ]
    return "\n".join(body)


def render_readme(records: list[dict]) -> str:
    package_lines: list[str] = []
    install_lines: list[str] = []
    for record in records:
        package_lines += [
            f"- {record['display']} {record['version']}: `{record['filename']}`",
            f"  - SHA-256: `{record['sha256']}`",
            f"  - Source: {record['url']}",
        ]
        install_lines.append(f"  ./{record['filename']} \\")

    install_lines[-1] = install_lines[-1].removesuffix(" \\")
    return f"""# Split offline wheels

These files are byte-for-byte split copies of Linux x86_64 wheels used for
offline ChatGPT sandbox setup. Each `.partNNN` file is at most **1,000,000
bytes** (about 976.6 KiB), which is strictly below 1 MiB (1,048,576 bytes).

## Included packages

{os.linesep.join(package_lines)}

## Automatic updates

`.github/workflows/update-binary-wheels.yml` checks PyPI weekly and can also be
run manually. It selects the newest stable wheel compatible with CPython 3.13
on Linux x86_64, verifies the SHA-256 published by PyPI, refreshes the split
parts and license notices, reconstructs the wheels, runs an
assemble/disassemble smoke test, and commits only when the vendored artifacts
actually change.

## Reassemble

```bash
cd third_party/wheels
./reassemble.sh
```

`PARTS-SHA256SUMS` verifies each tracked chunk. `SHA256SUMS` verifies the
reconstructed wheels against PyPI metadata.

## Offline install

```bash
python3 -m pip install --no-index --no-deps \\
{os.linesep.join(install_lines)}
```

## Licensing

Capstone and the Keystone Python binding are third-party software. Their
redistribution notices are reproduced as `CAPSTONE-LICENSE.txt` and
`KEYSTONE-LICENSE.txt`; those packages are not covered by this repository's
MIT license.
"""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--check-only",
        action="store_true",
        help="select/download/verify only; do not rewrite repository files",
    )
    args = parser.parse_args()

    OUT.mkdir(parents=True, exist_ok=True)
    records: list[dict] = []

    with tempfile.TemporaryDirectory(prefix="wheel-update-") as temp_dir:
        temp = Path(temp_dir)

        for package in PACKAGES:
            version, item = pick_latest(package["project"])
            filename = item["filename"]
            wheel = temp / filename

            download(item["url"], wheel)
            actual = sha256_file(wheel)
            expected = item.get("digests", {}).get("sha256")
            if not expected or actual != expected:
                raise RuntimeError(
                    f"SHA-256 mismatch for {filename}: expected {expected}, got {actual}"
                )

            records.append(
                {
                    **package,
                    "version": version,
                    "filename": filename,
                    "sha256": actual,
                    "url": item["url"],
                    "wheel": wheel,
                    "license": extract_license(wheel),
                }
            )

        if args.check_only:
            for record in records:
                print(
                    f"{record['project']} {record['version']} "
                    f"{record['filename']} {record['sha256']}"
                )
            return 0

        for old in OUT.glob("*.whl.part*"):
            old.unlink()

        parts: list[Path] = []
        for record in records:
            parts.extend(split_file(record["wheel"], OUT / record["filename"]))
            (OUT / record["license_file"]).write_bytes(record["license"])

        (OUT / "SHA256SUMS").write_text(
            "".join(
                f"{record['sha256']}  {record['filename']}\n"
                for record in records
            ),
            encoding="utf-8",
        )
        (OUT / "PARTS-SHA256SUMS").write_text(
            "".join(
                f"{sha256_file(part)}  {part.name}\n"
                for part in sorted(parts)
            ),
            encoding="utf-8",
        )

        reassemble = OUT / "reassemble.sh"
        reassemble.write_text(
            render_reassemble([record["filename"] for record in records]),
            encoding="utf-8",
        )
        reassemble.chmod(0o755)

        (OUT / "README.md").write_text(render_readme(records), encoding="utf-8")
        (OUT / "manifest.json").write_text(
            json.dumps(
                {
                    "target": f"CPython {PYTHON_VERSION_TEXT} / Linux x86_64",
                    "chunk_size_bytes": CHUNK_SIZE,
                    "strict_max_part_size_bytes": 1024 * 1024 - 1,
                    "packages": [
                        {
                            key: record[key]
                            for key in (
                                "project",
                                "display",
                                "version",
                                "filename",
                                "sha256",
                                "url",
                            )
                        }
                        for record in records
                    ],
                },
                indent=2,
                sort_keys=True,
            )
            + "\n",
            encoding="utf-8",
        )

    print("Updated vendored wheel set:")
    for record in records:
        print(f"  {record['display']} {record['version']} -> {record['filename']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
