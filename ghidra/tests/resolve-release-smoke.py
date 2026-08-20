#!/usr/bin/env python3
import importlib.util
import pathlib

module_path = pathlib.Path(__file__).parents[1] / "ci" / "resolve-release.py"
spec = importlib.util.spec_from_file_location("resolve_release", module_path)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

release = {
    "draft": False,
    "prerelease": False,
    "tag_name": "Ghidra_99.1_build",
    "html_url": "https://example.invalid/release",
    "published_at": "2099-01-01T00:00:00Z",
    "body": "",
    "assets": [{
        "id": 123,
        "name": "ghidra_99.1_PUBLIC_20990101.zip",
        "url": "https://api.github.com/repos/x/y/releases/assets/123",
        "browser_download_url": "https://example.invalid/file.zip",
        "size": 42,
        "digest": "sha256:" + "ab" * 32,
    }],
}
result = mod.resolve(release)
assert result["version"] == "99.1"
assert result["sha256"] == "ab" * 32
assert result["filename"] == "ghidra_99.1_PUBLIC_20990101.zip"
print("release resolver smoke test passed")
