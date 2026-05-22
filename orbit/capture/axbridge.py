"""
Subprocess shim so macapptree's ["python", ...] calls resolve to the running
interpreter. macapptree/run.py lines 17, 27, 45 hardcode "python"; patching
subprocess before the import fixes it without touching the venv.
"""
from __future__ import annotations
import sys
import subprocess as _subprocess

_real_check_call = _subprocess.check_call
_real_run = _subprocess.run


def _patch_cmd(cmd):
    if isinstance(cmd, list) and cmd and cmd[0] == "python":
        return [sys.executable] + cmd[1:]
    return cmd


_subprocess.check_call = lambda cmd, **kw: _real_check_call(_patch_cmd(cmd), **{"stdout": _subprocess.DEVNULL, **kw})
_subprocess.run = lambda cmd, **kw: _real_run(_patch_cmd(cmd), **{"stdout": _subprocess.DEVNULL, **kw})

from macapptree import get_tree, get_app_bundle  # noqa: E402

__all__ = ["get_tree", "get_app_bundle"]
