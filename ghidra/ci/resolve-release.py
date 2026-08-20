#!/usr/bin/env python3
"""Resolve the latest usable public Ghidra GitHub release and its digest."""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.request

API = "https://api.github.com/repos/NationalSecurityAgency/ghidra/releases/latest"
ASSET_RE = re.compile(r"^ghidra_(?P<version>[0-9.]+)_PUBLIC_(?P<date>[0-9]{8})\.zip$")
SHA_RE = re.compile(r"(?i)sha-?256[^0-9a-f]+([0-9a-f]{64})")


def request_json(url: str) -> dict:
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "chatgpt-sandbox-kit",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=60) as response:
        return json.load(response)


def resolve(release: dict) -> dict:
    if release.get("draft") or release.get("prerelease"):
        raise ValueError("latest release is not a stable public release")
    candidates = []
    for asset in release.get("assets", []):
        match = ASSET_RE.match(asset.get("name", ""))
        if match:
            candidates.append((asset, match))
    if len(candidates) != 1:
        raise ValueError(f"expected one public Ghidra ZIP, found {len(candidates)}")

    asset, match = candidates[0]
    digest = asset.get("digest") or ""
    if digest.startswith("sha256:"):
        sha256 = digest.split(":", 1)[1].lower()
    else:
        body = release.get("body") or ""
        sha_match = SHA_RE.search(body)
        if not sha_match:
            raise ValueError("release asset has no SHA-256 digest and release body has no SHA-256")
        sha256 = sha_match.group(1).lower()

    return {
        "tag": release["tag_name"],
        "release_url": release["html_url"],
        "published_at": release.get("published_at"),
        "version": match.group("version"),
        "filename": asset["name"],
        "asset_url": asset["url"],
        "browser_download_url": asset["browser_download_url"],
        "asset_id": asset["id"],
        "size": asset["size"],
        "sha256": sha256,
        # Current Ghidra releases expose Java requirements in the ZIP. This is
        # a bootstrap hint for setup-java; package-release validates/rewrites it.
        "java_min": 21,
    }


def write_github_output(path: str, result: dict, release_json_path: str) -> None:
    with open(path, "a", encoding="utf-8") as out:
        for key in ("tag", "version", "filename", "sha256", "java_min"):
            out.write(f"{key}={result[key]}\n")
        out.write(f"release_json={release_json_path}\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", help="Use a saved GitHub release JSON instead of the API")
    parser.add_argument("--github-output")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    release = json.load(open(args.input, encoding="utf-8")) if args.input else request_json(API)
    result = resolve(release)

    release_json_path = os.path.abspath(args.input) if args.input else os.path.abspath("release.json")
    if not args.input:
        with open(release_json_path, "w", encoding="utf-8") as f:
            json.dump(release, f)

    if args.github_output:
        write_github_output(args.github_output, result, release_json_path)
    if args.json or not args.github_output:
        json.dump(result, sys.stdout, indent=2)
        sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
