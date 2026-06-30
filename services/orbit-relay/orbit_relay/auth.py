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


def hash_password(password: str) -> str:
    salt = secrets.token_hex(16)
    digest = hashlib.pbkdf2_hmac(
        "sha256", password.encode("utf-8"), salt.encode("utf-8"), 100_000
    )
    return f"{salt}${digest.hex()}"


def verify_password(password: str, stored: str) -> bool:
    salt, hex_digest = stored.split("$", 1)
    digest = hashlib.pbkdf2_hmac(
        "sha256", password.encode("utf-8"), salt.encode("utf-8"), 100_000
    )
    return hmac.compare_digest(digest.hex(), hex_digest)
