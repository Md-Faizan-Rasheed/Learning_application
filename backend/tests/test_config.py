"""Regression coverage for Settings.async_database_url's query-param
stripping — see the bug this guards against in app/config.py's module doc."""

from __future__ import annotations

from app.config import Settings


def test_strips_libpq_only_params_asyncpg_rejects():
    settings = Settings(
        jwt_secret="test-secret",
        database_url="postgresql://user:pass@host/db?sslmode=require&channel_binding=require",
    )
    assert settings.async_database_url == "postgresql+asyncpg://user:pass@host/db"


def test_keeps_query_params_asyncpg_does_understand():
    settings = Settings(
        jwt_secret="test-secret",
        database_url="postgresql://user:pass@host/db?application_name=myapp",
    )
    assert settings.async_database_url == "postgresql+asyncpg://user:pass@host/db?application_name=myapp"


def test_handles_url_with_no_query_string():
    settings = Settings(jwt_secret="test-secret", database_url="postgresql://user:pass@host/db")
    assert settings.async_database_url == "postgresql+asyncpg://user:pass@host/db"


def test_handles_postgres_scheme_alias():
    settings = Settings(
        jwt_secret="test-secret",
        database_url="postgres://user:pass@host/db?sslmode=require",
    )
    assert settings.async_database_url == "postgresql+asyncpg://user:pass@host/db"
