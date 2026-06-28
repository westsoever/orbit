"""FastAPI relay — device registration and rate-limited chat proxy."""
from __future__ import annotations

import hashlib
import json
import logging
import time
from contextlib import asynccontextmanager
from typing import Annotated

from fastapi import Depends, FastAPI, Header, HTTPException, Request
from pydantic import BaseModel, Field

from orbit_relay.config import Settings, get_settings
from orbit_relay.limits import (
    check_prompt_size,
    check_usage_after_increment,
    check_usage_before_request,
    estimate_tokens,
)
from orbit_relay.openrouter import complete_chat
from orbit_relay.store import (
    DuplicateInstallError,
    RegistrationLimitError,
    RelayStore,
)

logger = logging.getLogger(__name__)


class RegisterRequest(BaseModel):
    install_id: str = Field(..., min_length=8, max_length=128)
    app_version: str = Field(..., max_length=64)


class RegisterResponse(BaseModel):
    device_token: str
    expires_at: str


class ChatRequest(BaseModel):
    system: str = Field(..., max_length=32_000)
    user: str = Field(..., max_length=32_000)
    model: str = Field("owl-alpha", max_length=128)


class ChatResponse(BaseModel):
    content: str


def _client_ip(request: Request) -> str:
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    if request.client:
        return request.client.host
    return "unknown"


def _device_id_hash(device_id: str) -> str:
    return hashlib.sha256(device_id.encode()).hexdigest()[:16]


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    app.state.store = RelayStore(settings.database_path)
    logging.basicConfig(level=logging.INFO)
    yield


app = FastAPI(title="Orbit Cloud AI Relay", version="0.1.0", lifespan=lifespan)


def get_store(request: Request) -> RelayStore:
    return request.app.state.store


@app.get("/health")
async def health() -> dict[str, bool]:
    return {"ok": True}


@app.post("/v1/devices/register", status_code=201, response_model=RegisterResponse)
async def register_device(
    body: RegisterRequest,
    request: Request,
    settings: Annotated[Settings, Depends(get_settings)],
    store: Annotated[RelayStore, Depends(get_store)],
    x_orbit_invite: Annotated[str | None, Header()] = None,
) -> RegisterResponse:
    if settings.relay_disabled:
        raise HTTPException(status_code=503, detail={"error": "relay_disabled"})

    if settings.invite_code and x_orbit_invite != settings.invite_code:
        raise HTTPException(status_code=403, detail={"error": "invalid_invite"})

    client_ip = _client_ip(request)
    try:
        token, expires_at = store.register_device(
            install_id=body.install_id,
            secret=settings.orbit_relay_secret,
            token_ttl_days=settings.token_ttl_days,
            client_ip=client_ip,
            max_registrations_per_ip=settings.max_registrations_per_ip_per_day,
        )
    except DuplicateInstallError:
        raise HTTPException(status_code=409, detail={"error": "install_id_already_registered"})
    except RegistrationLimitError:
        raise HTTPException(status_code=429, detail={"error": "registration_limit_exceeded"})

    logger.info(
        "%s",
        json.dumps(
            {
                "event": "device_registered",
                "install_id": body.install_id,
                "ip": client_ip,
                "app_version": body.app_version,
            }
        ),
    )
    return RegisterResponse(device_token=token, expires_at=expires_at)


@app.post("/v1/chat/completions", response_model=ChatResponse)
async def chat_completions(
    body: ChatRequest,
    request: Request,
    settings: Annotated[Settings, Depends(get_settings)],
    store: Annotated[RelayStore, Depends(get_store)],
    authorization: Annotated[str | None, Header()] = None,
) -> ChatResponse:
    if settings.relay_disabled:
        raise HTTPException(status_code=503, detail={"error": "relay_disabled"})

    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail={"error": "invalid_token"})

    token = authorization[7:].strip()
    device = store.resolve_device(token, settings.orbit_relay_secret)
    if device is None:
        raise HTTPException(status_code=401, detail={"error": "invalid_token"})

    prompt_check = check_prompt_size(body.system, body.user, settings)
    if not prompt_check.allowed:
        raise HTTPException(status_code=prompt_check.status_code, detail={"error": prompt_check.error})

    client_ip = _client_ip(request)
    tokens_est = estimate_tokens(body.system, body.user)
    day = store.day_utc()

    pre_check = check_usage_before_request(
        store, device.device_id, client_ip, tokens_est, settings
    )
    if not pre_check.allowed:
        raise HTTPException(
            status_code=pre_check.status_code,
            detail={"error": pre_check.error, "retry_after": pre_check.retry_after},
        )

    device_requests, device_tokens, ip_requests = store.record_usage(
        device.device_id, client_ip, day, tokens_est
    )
    post_check = check_usage_after_increment(
        device_requests, device_tokens, ip_requests, settings
    )
    if not post_check.allowed:
        raise HTTPException(
            status_code=post_check.status_code,
            detail={"error": post_check.error, "retry_after": post_check.retry_after},
        )

    started = time.perf_counter()
    try:
        content = await complete_chat(body.system, body.user, body.model, settings)
    except Exception:
        logger.exception(
            "chat_failed device_id_hash=%s status=502",
            _device_id_hash(device.device_id),
        )
        raise HTTPException(status_code=502, detail={"error": "upstream_unavailable"})

    latency_ms = int((time.perf_counter() - started) * 1000)
    logger.info(
        "%s",
        json.dumps(
            {
                "event": "chat",
                "device_id_hash": _device_id_hash(device.device_id),
                "status": 200,
                "tokens_est": tokens_est,
                "latency_ms": latency_ms,
            }
        ),
    )
    return ChatResponse(content=content)


def run() -> None:
    import uvicorn

    uvicorn.run("orbit_relay.main:app", host="0.0.0.0", port=8080, reload=False)


if __name__ == "__main__":
    run()
