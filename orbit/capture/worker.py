from __future__ import annotations

import datetime
import json
import logging
import queue
import time
from typing import Any

from orbit.capture.axbridge import get_tree
from orbit.capture.extract import flatten_text_atoms
from orbit.storage.writer import record_event

logger = logging.getLogger(__name__)

def run_capture_worker(
    focus_queue: queue.Queue,
    embed_queue: queue.Queue | None,
    con,
    lock,
    max_depth: int = 12,
    on_capture_start=None,
    on_capture_done=None,
) -> None:
    logger.info("Capture worker started")
    while True:
        try:
            event = focus_queue.get(timeout=1.0)
        except queue.Empty:
            continue
        if event is None:
            break

        bundle = event["bundle_id"]
        app_name = event["app_name"]
        try:
            if on_capture_start:
                on_capture_start()
            tree = get_tree(bundle, max_depth=max_depth)
            if on_capture_done:
                on_capture_done()
        except Exception:
            logger.exception("get_tree failed for %s", bundle)
            continue

        atoms = flatten_text_atoms(tree)
        if not atoms:
            continue

        window_title = None
        for node in tree:
            if node.get("role") == "AXWindow":
                window_title = node.get("name") or node.get("title")
                break

        visible_texts = [a["text"] for a in atoms[:5]]

        ev_dict: dict[str, Any] = {
            "timestamp": datetime.datetime.utcnow().isoformat(),
            "app_bundle_id": bundle,
            "app_name": app_name,
            "window_title": window_title,
            "focused_element_role": atoms[0]["role"] if atoms else None,
            "focused_element_label": atoms[0]["label"] if atoms else None,
            "visible_text": " | ".join(visible_texts),
            "raw_json": tree,
        }

        try:
            event_id, atom_ids = record_event(con, lock, ev_dict, atoms)
            logger.info("Captured event %d for %s (%d atoms)", event_id, bundle, len(atoms))
        except Exception:
            logger.exception("record_event failed for %s", bundle)
            continue

        if embed_queue is not None:
            for aid, atom in zip(atom_ids, atoms):
                embed_queue.put((event_id, aid, atom["text"]))
