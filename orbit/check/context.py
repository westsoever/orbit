"""Read context — from capture DB, GitHub daily report, or a local file."""
from __future__ import annotations
import shutil
import subprocess
import sqlite3
from datetime import date as _date
from pathlib import Path

_GITHUB_REPO = "westsoever/cos"
_GITHUB_BRANCH = "main"
_DAILY_REPORT_DIR = "06-wiki/daily_report"
LOCAL_DEFAULT = Path("~/.orbit/context.md").expanduser()


def read_capture(
    con: sqlite3.Connection,
    *,
    hours: int = 4,
    user_id: str | None = None,
) -> tuple[str, str]:
    from orbit.check.capture_context import read_capture_context

    return read_capture_context(con, hours=hours, user_id=user_id)


def read_github(
    repo: str = _GITHUB_REPO,
    branch: str = _GITHUB_BRANCH,
    date: str | None = None,
) -> str:
    """Fetch a daily report from GitHub using the gh CLI.

    Raises FileNotFoundError if gh is absent, the file doesn't exist, or the
    request fails for any reason.
    """
    if shutil.which("gh") is None:
        raise FileNotFoundError("gh CLI not found — install it or use --source local")

    d = date or _date.today().isoformat()
    path = f"{_DAILY_REPORT_DIR}/{d}.md"

    result = subprocess.run(
        ["gh", "api", f"repos/{repo}/contents/{path}",
         "-H", "Accept: application/vnd.github.v3.raw",
         "--method", "GET"],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        msg = result.stderr.strip() or f"HTTP error for {path}"
        raise FileNotFoundError(
            f"Daily report not found for {d} in {repo}/{branch}\n  {msg}"
        )
    return result.stdout.strip()


def read_local(path: str | Path | None = None) -> str:
    p = Path(path).expanduser() if path else LOCAL_DEFAULT
    if not p.exists():
        raise FileNotFoundError(
            f"Context file not found: {p}\n"
            f"Create it at {p} or use --source github"
        )
    return p.read_text(encoding="utf-8").strip()


def read_context(
    local_path: str | Path | None = None,
    source: str = "capture",
    date: str | None = None,
    *,
    con: sqlite3.Connection | None = None,
    capture_hours: int = 4,
) -> tuple[str, str]:
    """Return (context_text, source_label).

    source: "capture" | "github" | "local"
    """
    if source == "capture":
        if con is None:
            raise ValueError("database connection required for capture source")
        return read_capture(con, hours=capture_hours)
    if source == "github":
        try:
            text = read_github(date=date)
            d = date or _date.today().isoformat()
            return text, f"{_GITHUB_REPO}/{_DAILY_REPORT_DIR}/{d}.md"
        except FileNotFoundError as e:
            # Try local fallback
            try:
                text = read_local(local_path)
                return text, str(local_path or LOCAL_DEFAULT)
            except FileNotFoundError:
                raise FileNotFoundError(
                    f"GitHub fetch failed and no local fallback found.\n  {e}"
                ) from None
    else:
        text = read_local(local_path)
        return text, str(local_path or LOCAL_DEFAULT)
