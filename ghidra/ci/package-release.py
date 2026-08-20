#!/usr/bin/env python3
"""Download, verify, smoke-test, split, and manifest a Ghidra release asset."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import tempfile
import urllib.request
import zipfile
from pathlib import Path

CHUNK_SIZE = 64 * 1024 * 1024
APP_PROPERTIES_SUFFIX = "Ghidra/application.properties"


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def api_download(asset_url: str, destination: Path) -> None:
    headers = {
        "Accept": "application/octet-stream",
        "User-Agent": "chatgpt-sandbox-kit",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(asset_url, headers=headers)
    with urllib.request.urlopen(request, timeout=120) as response, destination.open("wb") as out:
        shutil.copyfileobj(response, out, length=1024 * 1024)


def parse_properties(zip_path: Path) -> dict[str, str]:
    with zipfile.ZipFile(zip_path) as zf:
        matches = [n for n in zf.namelist() if n.endswith(APP_PROPERTIES_SUFFIX)]
        if len(matches) != 1:
            raise RuntimeError(f"expected one {APP_PROPERTIES_SUFFIX}, found {len(matches)}")
        text = zf.read(matches[0]).decode("utf-8")
    props: dict[str, str] = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        props[key.strip()] = value.strip()
    return props


def smoke_test(zip_path: Path, expected_version: str) -> None:
    repo_root = Path(__file__).resolve().parents[2]
    with tempfile.TemporaryDirectory(prefix="ghidra-release-smoke-") as td:
        td_path = Path(td)
        tools = td_path / "tools"
        env = os.environ.copy()
        env["GHIDRA_TOOLS_ROOT"] = str(tools)
        subprocess.run(
            [str(repo_root / "ghidra/setup.sh"), "--archive", str(zip_path), "--skip-pyghidra"],
            env=env,
            check=True,
        )
        current = tools / "current"
        props = (current / "Ghidra/application.properties").read_text(encoding="utf-8")
        match = re.search(r"^application\.version=(.+)$", props, re.MULTILINE)
        if not match or match.group(1).strip() != expected_version:
            raise RuntimeError("installed version did not match release metadata")
        subprocess.run([str(repo_root / "ghidra/verify.sh"), "--full"], env=env, check=True)


def make_manifest(zip_path: Path, meta: dict, props: dict[str, str], outdir: Path) -> dict:
    outdir.mkdir(parents=True, exist_ok=True)
    for old in outdir.glob("part-*"):
        old.unlink()

    chunks = []
    with zip_path.open("rb") as src:
        index = 0
        while True:
            data = src.read(CHUNK_SIZE)
            if not data:
                break
            name = f"part-{index:03d}"
            path = outdir / name
            path.write_bytes(data)
            chunks.append({"file": name, "size": len(data), "sha256": hashlib.sha256(data).hexdigest()})
            index += 1

    manifest = {
        "schema": 1,
        "upstream": "NationalSecurityAgency/ghidra",
        "tag": meta["tag"],
        "release_url": meta["release_url"],
        "published_at": meta.get("published_at"),
        "version": props.get("application.version", meta["version"]),
        "filename": meta["filename"],
        "size": zip_path.stat().st_size,
        "sha256": meta["sha256"],
        "java_min": int(props["application.java.min"]),
        "chunk_size": CHUNK_SIZE,
        "chunks": chunks,
    }
    (outdir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return manifest


def reassemble_and_verify(outdir: Path, original: Path, manifest: dict) -> None:
    rebuilt = outdir / ".rebuilt.zip"
    with rebuilt.open("wb") as out:
        for part in manifest["chunks"]:
            path = outdir / part["file"]
            if path.stat().st_size != part["size"] or sha256(path) != part["sha256"]:
                raise RuntimeError(f"chunk verification failed: {path.name}")
            with path.open("rb") as src:
                shutil.copyfileobj(src, out)
    if sha256(rebuilt) != manifest["sha256"]:
        raise RuntimeError("reassembled archive digest mismatch")
    subprocess.run(["cmp", "--silent", str(original), str(rebuilt)], check=True)
    rebuilt.unlink()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--release-json", required=True)
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--smoke-test", action="store_true")
    args = parser.parse_args()

    from resolve_release import resolve

    release = json.load(open(args.release_json, encoding="utf-8"))
    meta = resolve(release)
    outdir = Path(args.output_dir).resolve()
    outdir.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="ghidra-release-") as td:
        archive = Path(td) / meta["filename"]
        api_download(meta["asset_url"], archive)
        actual = sha256(archive)
        if actual != meta["sha256"]:
            raise RuntimeError(f"upstream SHA-256 mismatch: expected {meta['sha256']}, got {actual}")
        if archive.stat().st_size != meta["size"]:
            raise RuntimeError("upstream asset size mismatch")

        props = parse_properties(archive)
        version = props.get("application.version")
        if version != meta["version"]:
            raise RuntimeError(f"ZIP application.version {version!r} != release filename version {meta['version']!r}")
        if "application.java.min" not in props:
            raise RuntimeError("ZIP is missing application.java.min")

        # setup.sh accepts manifest-backed future releases; give smoke_test one.
        sidecar = Path(str(archive) + ".manifest.json")
        sidecar.write_text(json.dumps({
            "version": version,
            "filename": meta["filename"],
            "sha256": meta["sha256"],
            "java_min": int(props["application.java.min"]),
        }) + "\n", encoding="utf-8")

        if args.smoke_test:
            smoke_test(archive, version)

        manifest = make_manifest(archive, meta, props, outdir)
        reassemble_and_verify(outdir, archive, manifest)

    print(json.dumps(manifest, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
