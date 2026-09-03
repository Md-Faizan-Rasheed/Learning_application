"""Auth is both the most security-sensitive code in this backend and the
most recently changed (account deletion, password reset, the X-Admin-Key
backdoor removal all landed this session) — these are the highest-value
regression tests to have, not an attempt at full app coverage."""

from __future__ import annotations

import uuid

from sqlalchemy import text

from app.db import SessionLocal


def _unique_email() -> str:
    return f"pytest-{uuid.uuid4().hex[:10]}@example.com"


async def _delete_account(client, token: str, password: str | None = None):
    # httpx 0.28's AsyncClient.delete() doesn't accept a body at all (by
    # design) — .request("DELETE", ...) is the way to send one.
    return await client.request(
        "DELETE",
        "/auth/account",
        headers={"Authorization": f"Bearer {token}"},
        json={"password": password} if password is not None else {},
    )


async def test_register_rejects_duplicate_email_and_login_checks_password(client):
    email = _unique_email()
    reg = await client.post(
        "/auth/register",
        json={"email": email, "password": "TestPass123!", "display_name": "PytestUser", "gender": "male"},
    )
    assert reg.status_code == 201
    token = reg.json()["access_token"]

    dup = await client.post(
        "/auth/register",
        json={"email": email, "password": "TestPass123!", "display_name": "Dup", "gender": "male"},
    )
    assert dup.status_code == 409

    wrong = await client.post("/auth/login", json={"email": email, "password": "WrongPass!"})
    assert wrong.status_code == 401

    ok = await client.post("/auth/login", json={"email": email, "password": "TestPass123!"})
    assert ok.status_code == 200

    await _delete_account(client, token, "TestPass123!")


async def test_account_deletion_requires_correct_password(client):
    email = _unique_email()
    reg = await client.post(
        "/auth/register",
        json={"email": email, "password": "TestPass123!", "display_name": "PytestDel", "gender": "male"},
    )
    token = reg.json()["access_token"]

    wrong = await _delete_account(client, token, "wrong")
    assert wrong.status_code == 401

    still_there = await client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert still_there.status_code == 200

    deleted = await _delete_account(client, token, "TestPass123!")
    assert deleted.status_code == 204

    gone = await client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert gone.status_code == 404


async def test_guest_account_deletion_needs_no_password(client):
    reg = await client.post("/auth/guest", json={"display_name": "PytestGuest", "gender": "male"})
    assert reg.status_code == 201
    token = reg.json()["access_token"]

    res = await _delete_account(client, token)
    assert res.status_code == 204


async def test_forgot_password_does_not_leak_which_emails_are_registered(client):
    email = _unique_email()
    reg = await client.post(
        "/auth/register",
        json={"email": email, "password": "OldPass123!", "display_name": "PytestLeak", "gender": "male"},
    )
    token = reg.json()["access_token"]

    known = await client.post("/auth/forgot-password", json={"email": email})
    unknown = await client.post("/auth/forgot-password", json={"email": _unique_email()})
    assert known.status_code == unknown.status_code == 200
    assert known.json() == unknown.json()

    await _delete_account(client, token, "OldPass123!")


async def test_reset_password_full_happy_path(client):
    email = _unique_email()
    reg = await client.post(
        "/auth/register",
        json={"email": email, "password": "OldPass123!", "display_name": "PytestReset", "gender": "male"},
    )
    assert reg.status_code == 201

    forgot = await client.post("/auth/forgot-password", json={"email": email})
    assert forgot.status_code == 200

    async with SessionLocal() as db:
        row = (
            await db.execute(text("SELECT password_reset_token FROM users WHERE email = :e"), {"e": email})
        ).first()
    token = row[0] if row else None
    assert token, "forgot-password should have set a reset token"

    bogus = await client.post(
        "/auth/reset-password", json={"token": "not-a-real-token", "new_password": "SomePass123!"}
    )
    assert bogus.status_code == 400

    reset = await client.post("/auth/reset-password", json={"token": token, "new_password": "NewPass123!"})
    assert reset.status_code == 200

    reused = await client.post("/auth/reset-password", json={"token": token, "new_password": "AnotherPass1!"})
    assert reused.status_code == 400, "a reset token must be single-use"

    old_login = await client.post("/auth/login", json={"email": email, "password": "OldPass123!"})
    assert old_login.status_code == 401

    new_login = await client.post("/auth/login", json={"email": email, "password": "NewPass123!"})
    assert new_login.status_code == 200
    new_token = new_login.json()["access_token"]

    await _delete_account(client, new_token, "NewPass123!")


async def test_admin_endpoints_reject_fake_x_admin_key_header(client):
    """Regression test for the removed X-Admin-Key backdoor: a header that
    used to be a valid bypass must now be fully ignored."""
    res = await client.get("/admin/categories", headers={"X-Admin-Key": "anything"})
    assert res.status_code == 403
