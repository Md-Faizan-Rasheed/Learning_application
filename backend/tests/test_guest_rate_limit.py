from __future__ import annotations

import uuid

import pytest


@pytest.mark.asyncio
async def test_guest_creation_is_limited_by_request_ip(client, monkeypatch):
    from app.auth import routes as auth_routes
    from app.auth import schemas as auth_schemas
    from app.common.deps import get_db
    from app.main import app

    calls: list[dict] = []

    async def capture_limit(**kwargs):
        calls.append(kwargs)

    async def fake_get_db():
        yield object()

    async def fake_create_guest(db, *, display_name: str, gender: str):
        return {"id": uuid.uuid4(), "display_name": display_name, "role": "player"}

    monkeypatch.setattr(auth_routes, "rate_limit", capture_limit)
    monkeypatch.setattr(auth_schemas, "create_guest", fake_create_guest)
    app.dependency_overrides[get_db] = fake_get_db
    try:
        response = await client.post(
            "/auth/guest",
            json={"display_name": "Guest test", "gender": "male"},
        )
    finally:
        app.dependency_overrides.pop(get_db, None)

    assert response.status_code == 201
    assert len(calls) == 1
    assert calls[0]["key"].startswith("guest:")
    assert calls[0]["limit"] == 5
    assert calls[0]["window_seconds"] == 60
