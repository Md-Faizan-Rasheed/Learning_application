"""Shared pytest fixtures. Tests run against the app's plain FastAPI instance
(not the Socket.IO-wrapped asgi_app — REST auth endpoints don't need that
layer) over an in-process ASGI transport, and against the real local dev
Postgres pointed to by backend/.env — there's no separate test database yet,
so every test uses a uniquely-generated email and cleans up after itself,
the same pattern used for manual verification throughout this project."""

from __future__ import annotations

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient

from app.main import app


@pytest.fixture(autouse=True)
def _disable_auth_rate_limit(monkeypatch):
    """auth/routes.py rate-limits login/register/forgot-password/reset-password
    by caller IP (see common/rate_limit.py) — real brute-force protection in
    production, but every call in this suite shares one fake IP (httpx's
    ASGITransport), and several test files register a fresh user each, so a
    full run would trip the limiter well before it got through all of them.
    The limiter itself has no test coverage gap from this: it's exercised
    manually against the live dev server instead."""

    async def _noop(**kwargs):
        return None

    monkeypatch.setattr("app.auth.routes.rate_limit", _noop)


@pytest_asyncio.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c
