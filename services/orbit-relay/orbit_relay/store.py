"""SQLite persistence for devices and usage counters."""
from __future__ import annotations

import sqlite3
import uuid
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from pathlib import Path

from orbit_relay.auth import generate_device_token, hash_token


@dataclass(frozen=True)
class DeviceRecord:
    device_id: str
    install_id: str
    token_hash: str
    created_at: str
    expires_at: str
    revoked: bool


_SCHEMA = """
CREATE TABLE IF NOT EXISTS devices (
  id TEXT PRIMARY KEY,
  install_id TEXT UNIQUE NOT NULL,
  token_hash TEXT NOT NULL,
  created_at TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  revoked INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS usage_daily (
  device_id TEXT NOT NULL,
  day_utc TEXT NOT NULL,
  requests INTEGER NOT NULL DEFAULT 0,
  tokens_est INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (device_id, day_utc)
);

CREATE TABLE IF NOT EXISTS ip_usage_daily (
  ip TEXT NOT NULL,
  day_utc TEXT NOT NULL,
  requests INTEGER NOT NULL DEFAULT 0,
  registrations INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (ip, day_utc)
);
"""


class RelayStore:
    def __init__(self, path: str) -> None:
        self._path = path
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        with self._connect() as con:
            con.executescript(_SCHEMA)

    @contextmanager
    def _connect(self):
        con = sqlite3.connect(self._path, check_same_thread=False)
        con.row_factory = sqlite3.Row
        try:
            yield con
            con.commit()
        finally:
            con.close()

    @staticmethod
    def day_utc() -> str:
        return datetime.now(UTC).strftime("%Y-%m-%d")

    def register_device(
        self,
        install_id: str,
        secret: str,
        token_ttl_days: int,
        client_ip: str,
        max_registrations_per_ip: int,
    ) -> tuple[str, str]:
        """Return (raw_device_token, expires_at_iso)."""
        now = datetime.now(UTC)
        expires_at = now + timedelta(days=token_ttl_days)
        expires_iso = expires_at.isoformat()

        with self._connect() as con:
            existing = con.execute(
                "SELECT install_id FROM devices WHERE install_id = ?",
                (install_id,),
            ).fetchone()
            if existing is not None:
                raise DuplicateInstallError(install_id)

            day = self.day_utc()
            ip_row = con.execute(
                "SELECT registrations FROM ip_usage_daily WHERE ip = ? AND day_utc = ?",
                (client_ip, day),
            ).fetchone()
            registrations = int(ip_row["registrations"]) if ip_row else 0
            if registrations >= max_registrations_per_ip:
                raise RegistrationLimitError(client_ip)

            token = generate_device_token()
            device_id = str(uuid.uuid4())
            con.execute(
                """
                INSERT INTO devices (id, install_id, token_hash, created_at, expires_at, revoked)
                VALUES (?, ?, ?, ?, ?, 0)
                """,
                (
                    device_id,
                    install_id,
                    hash_token(token, secret),
                    now.isoformat(),
                    expires_iso,
                ),
            )
            con.execute(
                """
                INSERT INTO ip_usage_daily (ip, day_utc, requests, registrations)
                VALUES (?, ?, 0, 1)
                ON CONFLICT(ip, day_utc) DO UPDATE SET registrations = registrations + 1
                """,
                (client_ip, day),
            )
        return token, expires_iso

    def resolve_device(self, token: str, secret: str) -> DeviceRecord | None:
        token_hash = hash_token(token, secret)
        with self._connect() as con:
            row = con.execute(
                """
                SELECT id, install_id, token_hash, created_at, expires_at, revoked
                  FROM devices
                 WHERE token_hash = ?
                """,
                (token_hash,),
            ).fetchone()
        if row is None:
            return None
        record = DeviceRecord(
            device_id=row["id"],
            install_id=row["install_id"],
            token_hash=row["token_hash"],
            created_at=row["created_at"],
            expires_at=row["expires_at"],
            revoked=bool(row["revoked"]),
        )
        if record.revoked:
            return None
        if datetime.fromisoformat(record.expires_at) < datetime.now(UTC):
            return None
        return record

    def get_usage(self, device_id: str, day_utc: str) -> tuple[int, int]:
        with self._connect() as con:
            row = con.execute(
                """
                SELECT requests, tokens_est FROM usage_daily
                 WHERE device_id = ? AND day_utc = ?
                """,
                (device_id, day_utc),
            ).fetchone()
        if row is None:
            return 0, 0
        return int(row["requests"]), int(row["tokens_est"])

    def get_ip_requests(self, ip: str, day_utc: str) -> int:
        with self._connect() as con:
            row = con.execute(
                "SELECT requests FROM ip_usage_daily WHERE ip = ? AND day_utc = ?",
                (ip, day_utc),
            ).fetchone()
        return int(row["requests"]) if row else 0

    def revoke_by_install_id(self, install_id: str) -> bool:
        with self._connect() as con:
            cur = con.execute(
                "UPDATE devices SET revoked = 1 WHERE install_id = ? AND revoked = 0",
                (install_id,),
            )
        return cur.rowcount > 0

    def record_usage(
        self,
        device_id: str,
        client_ip: str,
        day_utc: str,
        tokens_est: int,
    ) -> tuple[int, int, int]:
        """Increment counters; return (device_requests, device_tokens, ip_requests)."""
        with self._connect() as con:
            con.execute(
                """
                INSERT INTO usage_daily (device_id, day_utc, requests, tokens_est)
                VALUES (?, ?, 1, ?)
                ON CONFLICT(device_id, day_utc) DO UPDATE SET
                  requests = requests + 1,
                  tokens_est = tokens_est + excluded.tokens_est
                """,
                (device_id, day_utc, tokens_est),
            )
            con.execute(
                """
                INSERT INTO ip_usage_daily (ip, day_utc, requests, registrations)
                VALUES (?, ?, 1, 0)
                ON CONFLICT(ip, day_utc) DO UPDATE SET requests = requests + 1
                """,
                (client_ip, day_utc),
            )
            device_row = con.execute(
                "SELECT requests, tokens_est FROM usage_daily WHERE device_id = ? AND day_utc = ?",
                (device_id, day_utc),
            ).fetchone()
            ip_row = con.execute(
                "SELECT requests FROM ip_usage_daily WHERE ip = ? AND day_utc = ?",
                (client_ip, day_utc),
            ).fetchone()
        return (
            int(device_row["requests"]),
            int(device_row["tokens_est"]),
            int(ip_row["requests"]),
        )


class DuplicateInstallError(Exception):
    def __init__(self, install_id: str) -> None:
        self.install_id = install_id
        super().__init__(f"install_id already registered: {install_id}")


class RegistrationLimitError(Exception):
    def __init__(self, ip: str) -> None:
        self.ip = ip
        super().__init__(f"registration limit exceeded for ip: {ip}")
