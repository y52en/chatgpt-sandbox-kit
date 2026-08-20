#!/usr/bin/env python3
"""Import-compatible facade for the hyphenated release resolver CLI."""

from __future__ import annotations

import importlib.util
from pathlib import Path

_IMPL_PATH = Path(__file__).with_name("resolve-release.py")
_SPEC = importlib.util.spec_from_file_location("_ghidra_resolve_release_cli", _IMPL_PATH)
if _SPEC is None or _SPEC.loader is None:
    raise ImportError(f"could not load release resolver from {_IMPL_PATH}")
_IMPL = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(_IMPL)

resolve = _IMPL.resolve

__all__ = ["resolve"]
