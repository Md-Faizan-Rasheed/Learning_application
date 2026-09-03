"""Shared pytest fixtures. Tests run against the app's plain FastAPI instance
(not the Socket.IO-wrapped asgi_app — REST auth endpoints don't need that
layer) over an in-process ASGI transport, and against the real local dev
Postgres pointed to by backend/.env — there's no separate test database yet,
so every test uses a uniquely-generated email and cleans up after itself,
the same pattern used for manual verification throughout this project."""

from __future__ import annotations

import pytest_asyncio
from httpx import ASGITransport, AsyncClient

from app.main import app


@pytest_asyncio.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c
