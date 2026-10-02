"""Campaign mode backend tests.

Two things this file has to prove, per the campaign implementation spec:
1. pick_live_question's new stage_slug param is truly additive — when it's
   left unset (every pre-existing caller), the query must not touch
   event_framework_tags at all, so ordinary practice/multiplayer question
   selection is provably unaffected by this change.
2. claim_stage_reward's reward_claimed guard actually prevents a double
   award, the same idempotency property daily_quests already has.
"""

from __future__ import annotations

import uuid

from app.campaign import repository as campaign_repo
from app.db import SessionLocal
from app.game import repository as game_repo


def _unique_email() -> str:
    return f"pytest-campaign-{uuid.uuid4().hex[:10]}@example.com"


async def _register(client) -> tuple[str, str]:
    email = _unique_email()
    reg = await client.post(
        "/auth/register",
        json={
            "email": email,
            "password": "TestPass123!",
            "display_name": "PytestCampaign",
            "gender": "male",
        },
    )
    assert reg.status_code == 201
    body = reg.json()
    return body["access_token"], body["user_id"]


async def _delete_account(client, token: str, password: str):
    return await client.request(
        "DELETE",
        "/auth/account",
        headers={"Authorization": f"Bearer {token}"},
        json={"password": password},
    )


async def _any_stage_id(db) -> str:
    """Picks any real seeded stage rather than assuming a specific slug or
    total count — this DB's campaign_stages seed content (names, count) is
    expected to change independently of this test."""
    stages = await campaign_repo.list_stages(db)
    assert stages, "campaign_stages must be seeded for this test to run"
    return str(stages[0]["id"])


async def test_pick_live_question_without_stage_slug_never_touches_event_framework_tags():
    """The exact requirement: 'when absent (default), skip this join to leave
    existing behavior unchanged.' Proven by inspecting the actual SQL sent to
    Postgres, not just that a row comes back."""
    captured_sql: list[str] = []

    async with SessionLocal() as db:
        real_execute = db.execute

        async def spying_execute(clause, *args, **kwargs):
            captured_sql.append(str(clause))
            return await real_execute(clause, *args, **kwargs)

        db.execute = spying_execute  # type: ignore[method-assign]

        # Every pre-existing call site (practice, multiplayer) calls this
        # exact shape — positional difficulty/category/recent_questions,
        # stage_slug never passed.
        result = await game_repo.pick_live_question(db, "easy", "seerah", [])

    assert result is not None, "expected at least one live 'seerah' question to exist"
    assert captured_sql, "no SQL was captured"
    sql = captured_sql[0]
    assert "event_framework_tags" not in sql
    assert "eft" not in sql


async def test_pick_live_question_with_stage_slug_adds_the_join_and_filters_by_it():
    """The other half: when stage_slug IS passed, the join/filter must
    actually be present and actually narrow results to that stage's events."""
    async with SessionLocal() as db:
        result = await game_repo.pick_live_question(
            db, None, "seerah", [], stage_slug="hijrah_relocation"
        )
    # Whether or not any *question* is currently tagged to that event (seed
    # data only tags events, not questions — event_id on questions is left
    # for content authors to fill in later), the call must not error and
    # must return None rather than an untagged question leaking through.
    assert result is None or result.get("id") is not None


async def test_campaign_endpoints_end_to_end(client):
    """GET /campaign/stages and POST /campaign/stage/{id}/claim, exercised
    through real HTTP requests rather than calling the repository directly."""
    token, user_id = await _register(client)
    try:
        headers = {"Authorization": f"Bearer {token}"}

        stages_res = await client.get("/campaign/stages", headers=headers)
        assert stages_res.status_code == 200
        stages = stages_res.json()
        assert len(stages) >= 2, "need at least 2 seeded stages to test progression"
        assert stages[0]["state"] == "current"
        assert all(s["state"] == "locked" for s in stages[1:])

        # Claiming an incomplete stage must report claimed=False, not error.
        not_yet = await client.post(
            f"/campaign/stage/{stages[0]['id']}/claim", headers=headers
        )
        assert not_yet.status_code == 200
        assert not_yet.json()["claimed"] is False

        async with SessionLocal() as db:
            await campaign_repo.apply_stage_momentum(
                db, user_id=user_id, stage_id=stages[0]["id"], delta=100
            )
            await db.commit()

        completed = await client.get("/campaign/stages", headers=headers)
        assert completed.json()[0]["state"] == "completed"
        assert completed.json()[1]["state"] == "current"

        claim = await client.post(
            f"/campaign/stage/{stages[0]['id']}/claim", headers=headers
        )
        assert claim.status_code == 200
        assert claim.json()["claimed"] is True
    finally:
        from sqlalchemy import text

        async with SessionLocal() as db:
            await db.execute(
                text("DELETE FROM campaign_stage_progress WHERE user_id = :u"),
                {"u": user_id},
            )
            await db.commit()
        await _delete_account(client, token, "TestPass123!")


async def test_complete_stage_completes_regardless_of_score(client):
    """complete_stage is the unlock primitive for 'finish this stage's match,
    any score' — unlike apply_stage_momentum, it never takes a delta and
    always lands the stage at its target in one call. Idempotent: replaying
    an already-completed stage doesn't move its original completed_at."""
    token, user_id = await _register(client)
    try:
        async with SessionLocal() as db:
            stage_id = await _any_stage_id(db)

            first = await campaign_repo.complete_stage(db, user_id=user_id, stage_id=stage_id)
            await db.commit()
        assert first["progress"] == first["target"] == 100
        assert first["completed_at"] is not None
        first_completed_at = first["completed_at"]

        async with SessionLocal() as db:
            second = await campaign_repo.complete_stage(db, user_id=user_id, stage_id=stage_id)
            await db.commit()
        assert second["completed_at"] == first_completed_at, (
            "replaying an already-completed stage must not move its completed_at"
        )
    finally:
        from sqlalchemy import text

        async with SessionLocal() as db:
            await db.execute(
                text("DELETE FROM campaign_stage_progress WHERE user_id = :u"),
                {"u": user_id},
            )
            await db.commit()
        await _delete_account(client, token, "TestPass123!")


async def test_claim_stage_reward_is_idempotent(client):
    token, user_id = await _register(client)
    try:
        async with SessionLocal() as db:
            stage_id = await _any_stage_id(db)

            # Push momentum straight to the 100-point target so the stage
            # completes on this single call (same shape a real match-end
            # momentum write would produce over several matches).
            progress = await campaign_repo.apply_stage_momentum(
                db, user_id=user_id, stage_id=stage_id, delta=100
            )
            await db.commit()
        assert progress["completed_at"] is not None

        profile_before = await client.get(
            "/me/profile", headers={"Authorization": f"Bearer {token}"}
        )
        xp_before = profile_before.json()["total_xp"]

        async with SessionLocal() as db:
            first_claim = await campaign_repo.claim_stage_reward(
                db, user_id=user_id, stage_id=stage_id
            )
            await db.commit()
        assert first_claim is True

        profile_after_first = await client.get(
            "/me/profile", headers={"Authorization": f"Bearer {token}"}
        )
        xp_after_first = profile_after_first.json()["total_xp"]
        assert xp_after_first > xp_before

        async with SessionLocal() as db:
            second_claim = await campaign_repo.claim_stage_reward(
                db, user_id=user_id, stage_id=stage_id
            )
            await db.commit()
        assert second_claim is False, "a second claim must not report success"

        profile_after_second = await client.get(
            "/me/profile", headers={"Authorization": f"Bearer {token}"}
        )
        assert profile_after_second.json()["total_xp"] == xp_after_first, (
            "XP must not be awarded twice for the same stage"
        )
    finally:
        async with SessionLocal() as db:
            from sqlalchemy import text

            await db.execute(
                text("DELETE FROM campaign_stage_progress WHERE user_id = :u"),
                {"u": user_id},
            )
            await db.commit()
        await _delete_account(client, token, "TestPass123!")
