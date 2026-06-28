"""Relay configuration from environment variables."""
from __future__ import annotations

from functools import lru_cache

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    openrouter_api_key: str = Field(..., alias="OPENROUTER_API_KEY")
    orbit_relay_secret: str = Field(..., alias="ORBIT_RELAY_SECRET")
    daily_requests_per_device: int = Field(40, alias="DAILY_REQUESTS_PER_DEVICE")
    daily_tokens_per_device: int = Field(80_000, alias="DAILY_TOKENS_PER_DEVICE")
    daily_requests_per_ip: int = Field(200, alias="DAILY_REQUESTS_PER_IP")
    max_registrations_per_ip_per_day: int = Field(3, alias="MAX_REGISTRATIONS_PER_IP_PER_DAY")
    max_prompt_chars: int = Field(32_000, alias="MAX_PROMPT_CHARS")
    invite_code: str | None = Field(None, alias="INVITE_CODE")
    relay_disabled: bool = Field(False, alias="RELAY_DISABLED")
    database_path: str = Field("relay.db", alias="RELAY_DATABASE_PATH")
    default_model: str = Field("owl-alpha", alias="ORBIT_DEFAULT_MODEL")
    token_ttl_days: int = Field(365, alias="TOKEN_TTL_DAYS")
    openrouter_base_url: str = Field(
        "https://openrouter.ai/api/v1",
        alias="OPENROUTER_BASE_URL",
    )

    @field_validator("relay_disabled", mode="before")
    @classmethod
    def _parse_relay_disabled(cls, value: object) -> bool:
        if isinstance(value, str):
            return value.strip().lower() in {"1", "true", "yes", "on"}
        return bool(value)


@lru_cache
def get_settings() -> Settings:
    return Settings()
