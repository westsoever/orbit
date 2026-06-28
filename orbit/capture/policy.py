"""Capture policy — GDPR tier gates (plans/03-universal-capture.md Phase 3/5)."""

from __future__ import annotations

import json
from dataclasses import asdict, dataclass, field
from pathlib import Path

from orbit.capture.exclusions import EXCLUDED_BUNDLES

DEFAULT_POLICY_PATH = Path.home() / ".orbit" / "policy.json"


DEFAULT_WATCH_ROOTS = ["~/Projects"]


@dataclass
class CapturePolicy:
    tier_ax_text: bool = True
    tier_browser_ext: bool = True
    tier_ocr: bool = False
    tier_screenshot: bool = False
    tier_fsevents: bool = False
    excluded_bundles: list[str] = field(default_factory=list)
    ocr_allowlist: list[str] = field(default_factory=list)
    watch_roots: list[str] = field(default_factory=lambda: list(DEFAULT_WATCH_ROOTS))
    retention_days: int = 90
    work_hours_only: bool = False

    def is_bundle_blocked(self, bundle_id: str) -> bool:
        if bundle_id in EXCLUDED_BUNDLES:
            return True
        return bundle_id in self.excluded_bundles

    def ocr_allowed_for(self, bundle_id: str) -> bool:
        if not self.tier_ocr and not self.tier_screenshot:
            return False
        if self.is_bundle_blocked(bundle_id):
            return False
        if self.tier_screenshot and self.ocr_allowlist:
            return bundle_id in self.ocr_allowlist
        return self.tier_ocr


def load_policy(path: Path | None = None) -> CapturePolicy:
    path = path or DEFAULT_POLICY_PATH
    if not path.exists():
        return CapturePolicy()
    try:
        data = json.loads(path.read_text())
    except (json.JSONDecodeError, OSError):
        return CapturePolicy()
    watch = data.get("watch_roots")
    if watch is None:
        watch = list(DEFAULT_WATCH_ROOTS)
    return CapturePolicy(
        tier_ax_text=bool(data.get("tier_ax_text", True)),
        tier_browser_ext=bool(data.get("tier_browser_ext", True)),
        tier_ocr=bool(data.get("tier_ocr", False)),
        tier_screenshot=bool(data.get("tier_screenshot", False)),
        tier_fsevents=bool(data.get("tier_fsevents", False)),
        excluded_bundles=list(data.get("excluded_bundles") or []),
        ocr_allowlist=list(data.get("ocr_allowlist") or []),
        watch_roots=list(watch),
        retention_days=int(data.get("retention_days", 90)),
        work_hours_only=bool(data.get("work_hours_only", False)),
    )


def save_policy(policy: CapturePolicy, path: Path | None = None) -> None:
    path = path or DEFAULT_POLICY_PATH
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(asdict(policy), indent=2) + "\n")
