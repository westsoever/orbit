from __future__ import annotations

import queue
import logging
import threading
import time
import sqlite_vec
from sentence_transformers import SentenceTransformer
from orbit.storage.writer import record_embeddings

logger = logging.getLogger(__name__)

_MODEL: SentenceTransformer | None = None
_MODEL_LOCK = threading.Lock()

def _get_model() -> SentenceTransformer:
    global _MODEL
    if _MODEL is None:
        with _MODEL_LOCK:
            if _MODEL is None:
                _MODEL = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2")
                logger.info("Embedding model loaded on device: %s", _MODEL.device)
    return _MODEL

def run_embedding_worker(
    embed_queue: queue.Queue,
    con,
    lock,
    flush_ms: float = 200,
    batch_max: int = 32,
) -> None:
    model = _get_model()
    logger.info("Embedding worker started")
    while True:
        batch = []
        deadline = time.monotonic() + flush_ms / 1000.0
        try:
            item = embed_queue.get(timeout=flush_ms / 1000.0)
            if item is None:
                break
            batch.append(item)
            while len(batch) < batch_max:
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    break
                try:
                    item = embed_queue.get(timeout=remaining)
                    if item is None:
                        embed_queue.put(None)
                        break
                    batch.append(item)
                except queue.Empty:
                    break
        except queue.Empty:
            continue

        if not batch:
            continue

        try:
            texts = [t for (_, _, t) in batch]
            vectors = model.encode(texts, normalize_embeddings=True)
            payload = [sqlite_vec.serialize_float32(v.tolist()) for v in vectors]
            atom_ids = [aid for (_, aid, _) in batch]
            record_embeddings(con, lock, atom_ids, payload)
            logger.debug("Embedded %d atoms", len(batch))
        except Exception:
            logger.exception("Embedding batch failed")
