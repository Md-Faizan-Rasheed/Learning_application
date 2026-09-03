"""Report/block mechanism: the last item from the Play Store readiness audit.
Covers the player-facing report/block flows and the admin review queue."""

from __future__ import annotations

import uuid

from sqlalchemy import text

from app.db import SessionLocal


def _unique_email() -> str:
    return f"pytest-{uuid.uuid4().hex[:10]}@example.com"


async def _register(client, name: str) -> tuple[str, str]:
    """Returns (token, user_id)."""
    email = _unique_email()
    res = await client.post(
        "/auth/register",
        json={"email": email, "password": "TestPass123!", "display_name": name, "gender": "male"},
    )
    body = res.json()
    return body["access_token"], body["user_id"]


async def _delete_account(client, token: str, password: str = "TestPass123!"):
    return await client.request(
        "DELETE", "/auth/account",
        headers={"Authorization": f"Bearer {token}"},
        json={"password": password},
    )


async def _promote_admin(user_id: str) -> None:
    async with SessionLocal() as db:
        await db.execute(text("UPDATE users SET role = 'admin' WHERE id = :u"), {"u": user_id})
        await db.commit()


async def test_report_requires_a_real_target_and_rejects_self_report(client):
    token, user_id = await _register(client, "Reporter")

    self_report = await client.post(
        "/moderation/report",
        headers={"Authorization": f"Bearer {token}"},
        json={"reported_user_id": user_id, "reason": "spam"},
    )
    assert self_report.status_code == 400

    fake_target = await client.post(
        "/moderation/report",
        headers={"Authorization": f"Bearer {token}"},
        json={"reported_user_id": str(uuid.uuid4()), "reason": "spam"},
    )
    assert fake_target.status_code == 404

    await _delete_account(client, token)


async def test_report_full_flow_and_admin_review_queue(client):
    reporter_token, reporter_id = await _register(client, "Reporter2")
    target_token, target_id = await _register(client, "Target2")
    admin_token, admin_id = await _register(client, "Admin2")
    await _promote_admin(admin_id)
    # The token from register() is stamped with role='player' — promoting the
    # DB row doesn't retroactively change an already-issued JWT, so log back
    # in to get a fresh token that actually carries the 'admin' role.
    async with SessionLocal() as db:
        row = (await db.execute(text("SELECT email FROM users WHERE id = :u"), {"u": admin_id})).first()
    admin_login = await client.post(
        "/auth/login", json={"email": row[0], "password": "TestPass123!"}
    )
    assert admin_login.status_code == 200
    admin_token = admin_login.json()["access_token"]

    denied = await client.get("/admin/reports", headers={"Authorization": f"Bearer {reporter_token}"})
    assert denied.status_code == 403

    created = await client.post(
        "/moderation/report",
        headers={"Authorization": f"Bearer {reporter_token}"},
        json={"reported_user_id": target_id, "reason": "harassment", "details": "trash talk"},
    )
    assert created.status_code == 201
    report_id = created.json()["id"]
    assert created.json()["status"] == "open"

    queue = await client.get("/admin/reports", headers={"Authorization": f"Bearer {admin_token}"})
    assert queue.status_code == 200
    assert any(r["id"] == report_id for r in queue.json())

    reviewed = await client.patch(
        f"/admin/reports/{report_id}",
        headers={"Authorization": f"Bearer {admin_token}"},
        json={"status": "reviewed"},
    )
    assert reviewed.status_code == 200
    assert reviewed.json()["status"] == "reviewed"

    queue_after = await client.get("/admin/reports", headers={"Authorization": f"Bearer {admin_token}"})
    assert not any(r["id"] == report_id for r in queue_after.json())  # no longer 'open'

    await _delete_account(client, reporter_token)
    await _delete_account(client, target_token)
    await _delete_account(client, admin_token)


async def test_block_unblock_and_blocked_list(client):
    a_token, a_id = await _register(client, "Blocker")
    b_token, b_id = await _register(client, "Blockee")

    self_block = await client.post(
        "/moderation/block", headers={"Authorization": f"Bearer {a_token}"}, json={"user_id": a_id}
    )
    assert self_block.status_code == 400

    block = await client.post(
        "/moderation/block", headers={"Authorization": f"Bearer {a_token}"}, json={"user_id": b_id}
    )
    assert block.status_code == 201

    # blocking again is a no-op, not a conflict
    block_again = await client.post(
        "/moderation/block", headers={"Authorization": f"Bearer {a_token}"}, json={"user_id": b_id}
    )
    assert block_again.status_code == 201

    blocked_list = await client.get("/moderation/blocked", headers={"Authorization": f"Bearer {a_token}"})
    assert blocked_list.status_code == 200
    assert [b["user_id"] for b in blocked_list.json()] == [b_id]

    unblock = await client.delete(
        f"/moderation/block/{b_id}", headers={"Authorization": f"Bearer {a_token}"}
    )
    assert unblock.status_code == 204

    blocked_list_after = await client.get("/moderation/blocked", headers={"Authorization": f"Bearer {a_token}"})
    assert blocked_list_after.json() == []

    await _delete_account(client, a_token)
    await _delete_account(client, b_token)
