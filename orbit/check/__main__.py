"""orbit check — context-aware task detection and dispatch loop."""
from __future__ import annotations
import argparse
import os
import sys


def main() -> None:
    parser = argparse.ArgumentParser(
        prog="orbit check",
        description="Detect tasks from context.md and dispatch to Claude Code",
    )
    parser.add_argument("action", nargs="?", choices=["skipped"], default=None,
                        help="'skipped' to review today's skipped tasks")
    parser.add_argument("--context", default=None, help="Path to local context.md (used with --source local or as fallback)")
    parser.add_argument("--source", choices=["capture", "github", "local"], default="capture",
                        help="Context source: capture (default), github, or local")
    parser.add_argument("--capture-hours", type=int, default=4,
                        help="Hours of captured context when --source capture (default: 4)")
    parser.add_argument("--date", default=None, help="Report date YYYY-MM-DD (default: today)")
    parser.add_argument("--db", default="~/.orbit/orbit.db", help="SQLite DB path")
    parser.add_argument("--dry-run", action="store_true", help="Detect and print tasks; skip notification and dispatch")
    parser.add_argument("--no-notify", action="store_true", help="Skip macOS notification")
    parser.add_argument("--refresh", action="store_true", help="Re-run LLM detection even if today's tasks are cached")
    args = parser.parse_args()

    from orbit.check.context import read_context
    from orbit.check.detector import detect_tasks
    from orbit.check.notify import notify
    from orbit.check.approval import run_approval
    from orbit.check.dispatch import dispatch
    from orbit.check.log import insert_task, update_status, get_pending_today, get_skipped_today, migrate
    from orbit.storage.db import open_db_plain as open_db

    db_path = os.path.expanduser(args.db)
    os.makedirs(os.path.dirname(db_path), exist_ok=True)
    con, lock = open_db(db_path)
    migrate(con)

    # ── orbit check skipped ──────────────────────────────────────────
    if args.action == "skipped":
        cached = get_skipped_today(con, lock, report_date=args.date)
        if not cached:
            print("No skipped tasks today.")
            sys.exit(0)
        log_ids = {task.title: log_id for log_id, task in cached}
        tasks = [task for _, task in cached]
        print(f"{len(tasks)} skipped task(s) from today.")

    # ── orbit check (pending) ────────────────────────────────────────
    else:
        cached = get_pending_today(con, lock, report_date=args.date)
        if cached and not args.refresh:
            print(f"Resuming {len(cached)} pending task(s) from today (use --refresh to re-detect).")
            log_ids = {task.title: log_id for log_id, task in cached}
            tasks = [task for _, task in cached]
        else:
            try:
                context_text, source_label = read_context(
                    local_path=args.context,
                    source=args.source,
                    date=args.date,
                    con=con,
                    capture_hours=args.capture_hours,
                )
                print(f"Context: {source_label}")
            except FileNotFoundError as e:
                print(f"error: {e}", file=sys.stderr)
                sys.exit(1)

            print("Analysing context...", end=" ", flush=True)
            try:
                tasks = detect_tasks(context_text)
            except Exception as e:
                print(f"\nerror detecting tasks: {e}", file=sys.stderr)
                sys.exit(1)

            if not tasks:
                print("no tasks detected (all below confidence threshold).")
                sys.exit(0)

            print(f"{len(tasks)} task(s) detected.")
            log_ids = {t.title: insert_task(con, lock, t) for t in tasks}

    # ── dry run ──────────────────────────────────────────────────────
    if args.dry_run:
        for i, t in enumerate(tasks, 1):
            print(f"\n[{i}] {t.title}  (type={t.agent_type})")
            print(f"     {t.description}")
            snippet = t.suggested_prompt[:100].replace("\n", " ")
            print(f"     Prompt: {snippet}...")
        sys.exit(0)

    # ── notification ─────────────────────────────────────────────────
    if not args.no_notify:
        notify("Orbit", f"{len(tasks)} task(s) — {tasks[0].title}")

    # ── approval loop ────────────────────────────────────────────────
    def on_skip(task):
        update_status(con, lock, log_ids[task.title], "skipped")

    result = run_approval(tasks, on_skip=on_skip)

    if result is None:
        print("No tasks approved.")
        sys.exit(0)

    task, approved_prompt = result
    update_status(con, lock, log_ids[task.title], "approved", approved_prompt)

    # ── dispatch ─────────────────────────────────────────────────────
    exit_code = dispatch(approved_prompt, title=task.title)
    update_status(con, lock, log_ids[task.title], "dispatched", exit_code=exit_code)

    sys.exit(exit_code)


if __name__ == "__main__":
    main()
