"""Device token hashing and validation."""
from __future__ import annotations

import hashlib
import hmac
import secrets


def hash_token(token: str, secret: str) -> str:
    return hmac.new(secret.encode("utf-8"), token.encode("utf-8"), hashlib.sha256).hexdigest()


def generate_device_token() -> str:
    return secrets.token_urlsafe(32)


def verify_token(token: str, stored_hash: str, secret: str) -> bool:
    expected = hash_token(token, secret)
    return hmac.compare_digest(expected, stored_hash)
