"""
In-process accessibility-tree walker. Replaces macapptree.

Talks to AXUIElement directly via pyobjc — no subprocess, no NSApplication
activation (so no focus theft), no sleep, no feedback loop.

Output shape matches what flatten_text_atoms expects: a dict with
role / name / value / description / role_description / id / children.
"""
from __future__ import annotations

import logging
from typing import Any

from ApplicationServices import (
    AXUIElementCreateApplication,
    AXUIElementCopyAttributeValue,
    kAXErrorSuccess,
)

logger = logging.getLogger(__name__)

_ATTR_ROLE = "AXRole"
_ATTR_TITLE = "AXTitle"
_ATTR_VALUE = "AXValue"
_ATTR_DESC = "AXDescription"
_ATTR_ROLE_DESC = "AXRoleDescription"
_ATTR_ID = "AXIdentifier"
_ATTR_CHILDREN = "AXChildren"
_ATTR_WINDOWS = "AXWindows"
_ATTR_FOCUSED_WINDOW = "AXFocusedWindow"

# Cap total nodes visited so a runaway AXWebArea can't stall the worker.
_MAX_NODES = 5000


def _get(elem, attr):
    try:
        err, val = AXUIElementCopyAttributeValue(elem, attr, None)
    except Exception:
        return None
    if err != kAXErrorSuccess:
        return None
    return val


def _coerce_scalar(v):
    if v is None:
        return None
    if isinstance(v, (str, int, float, bool)):
        return v
    # NSString instances satisfy isinstance(str); anything else (AXValueRef,
    # CFArray, dict-likes) gets dropped — we only want plain text payloads.
    return None


def _walk(elem, depth_remaining: int, counter: list[int]) -> dict | None:
    if counter[0] >= _MAX_NODES:
        return None
    counter[0] += 1

    role = _get(elem, _ATTR_ROLE) or ""
    node: dict[str, Any] = {
        "role": str(role) if role else "",
        "name": _coerce_scalar(_get(elem, _ATTR_TITLE)),
        "value": _coerce_scalar(_get(elem, _ATTR_VALUE)),
        "description": _coerce_scalar(_get(elem, _ATTR_DESC)),
        "role_description": _coerce_scalar(_get(elem, _ATTR_ROLE_DESC)),
        "id": _coerce_scalar(_get(elem, _ATTR_ID)),
        "children": [],
    }

    if depth_remaining <= 0:
        return node

    children = _get(elem, _ATTR_CHILDREN) or []
    out_children = []
    for child in children:
        if counter[0] >= _MAX_NODES:
            break
        sub = _walk(child, depth_remaining - 1, counter)
        if sub is not None:
            out_children.append(sub)
    node["children"] = out_children
    return node


def get_tree(pid: int, max_depth: int = 12) -> dict:
    """Return the AX tree for the focused window of the app with this PID.

    Returns {} if the app has no AX-queryable windows (e.g. com.apple.dock).
    Never raises — failures collapse to an empty dict.
    """
    if not pid or pid <= 0:
        return {}
    try:
        app = AXUIElementCreateApplication(int(pid))
    except Exception:
        logger.debug("AXUIElementCreateApplication failed for pid=%s", pid, exc_info=True)
        return {}

    target = _get(app, _ATTR_FOCUSED_WINDOW)
    if target is None:
        windows = _get(app, _ATTR_WINDOWS) or []
        if not windows:
            return {}
        target = windows[0]

    counter = [0]
    tree = _walk(target, max_depth, counter)
    return tree or {}
