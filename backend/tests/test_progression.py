"""The /me/activity/complete endpoint is the only place a solo activity
(currently just Word Search) can earn real, persisted XP — everything else
about that feature is purely local to the client. Worth a real end-to-end
check against the DB, not just the pure xp_for_word_search formula."""

from __future__ import annotations

import uuid

from app.progression.rules import daily_score_for_word_search, xp_for_word_search


def _unique_email() -> str:
    return f"pytest-{uuid.uuid4().hex[:10]}@example.com"


async def _register(client) -> str:
    email = _unique_email()
    reg = await client.post(
        "/auth/register",
        json={
            "email": email,
            "password": "TestPass123!",
            "display_name": "PytestActivity",
            "gender": "male",
        },
    )
    assert reg.status_code == 201
    return reg.json()["access_token"]


async def _delete_account(client, token: str, password: str):
    return await client.request(
        "DELETE",
        "/auth/account",
        headers={"Authorization": f"Bearer {token}"},
        json={"password": password},
    )


def test_xp_for_word_search_rewards_words_found_and_penalizes_hints():
    no_hints = xp_for_word_search(difficulty="easy", words_found=6, hints_used=0)
    with_hints = xp_for_word_search(difficulty="easy", words_found=6, hints_used=3)
    assert with_hints < no_hints

    harder = xp_for_word_search(difficulty="hard", words_found=6, hints_used=0)
    assert harder > no_hints

    # Never negative, even with excessive hints.
    assert xp_for_word_search(difficulty="easy", words_found=0, hints_used=99) == 0


async def test_activity_complete_awards_xp_and_extends_streak(client):
    token = await _register(client)

    profile_before = await client.get(
        "/me/profile", headers={"Authorization": f"Bearer {token}"}
    )
    assert profile_before.status_code == 200
    xp_before = profile_before.json()["total_xp"]

    res = await client.post(
        "/me/activity/complete",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "activity": "word_search",
            "category": "prophets",
            "difficulty": "medium",
            "words_found": 8,
            "total_words": 8,
            "seconds": 90,
            "hints_used": 1,
        },
    )
    assert res.status_code == 200
    body = res.json()
    assert body["xp_earned"] > 0
    assert body["total_xp"] == xp_before + body["xp_earned"]
    assert body["streak_days"] >= 1
    assert body["streak_extended"] is True

    profile_after = await client.get(
        "/me/profile", headers={"Authorization": f"Bearer {token}"}
    )
    assert profile_after.json()["total_xp"] == body["total_xp"]

    await _delete_account(client, token, "TestPass123!")


async def test_activity_complete_tracks_distinct_words_found(client):
    token = await _register(client)
    headers = {"Authorization": f"Bearer {token}"}

    async def complete(words):
        res = await client.post(
            "/me/activity/complete",
            headers=headers,
            json={
                "activity": "word_search",
                "category": "prophets",
                "difficulty": "easy",
                "words_found": len(words),
                "total_words": len(words),
                "seconds": 30,
                "hints_used": 0,
                "words": words,
            },
        )
        assert res.status_code == 200

    await complete(["ADAM", "NUH", "MUSA"])
    await complete(["NUH", "ISA"])  # NUH repeats — should not double-count

    profile = await client.get("/me/profile", headers=headers)
    assert profile.json()["word_search_progress"]["prophets"] == 4

    await _delete_account(client, token, "TestPass123!")


async def _befriend(client, token_a: str, token_b: str) -> None:
    headers_a = {"Authorization": f"Bearer {token_a}"}
    headers_b = {"Authorization": f"Bearer {token_b}"}

    code = (await client.get("/social/me", headers=headers_b)).json()["friend_code"]
    await client.post(
        "/social/friends/requests", headers=headers_a, json={"friend_code": code}
    )
    incoming = (await client.get("/social/friends/requests", headers=headers_b)).json()
    request_id = incoming[0]["id"]
    resp = await client.post(
        f"/social/friends/requests/{request_id}/respond",
        headers=headers_b,
        json={"accept": True},
    )
    assert resp.status_code == 200


def test_daily_score_for_word_search_never_negative_and_rewards_speed():
    slow = daily_score_for_word_search(words_found=6, seconds=110, hints_used=0)
    fast = daily_score_for_word_search(words_found=6, seconds=10, hints_used=0)
    assert fast > slow

    hint_heavy = daily_score_for_word_search(words_found=1, seconds=200, hints_used=3)
    assert hint_heavy >= 0


async def test_daily_leaderboard_scopes_to_friends_and_ranks_by_score(client):
    token_a = await _register(client)
    token_b = await _register(client)
    token_stranger = await _register(client)
    await _befriend(client, token_a, token_b)

    async def play_daily(token, *, words_found, seconds):
        res = await client.post(
            "/me/activity/complete",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "activity": "word_search",
                "category": "prophets",
                "difficulty": "easy",
                "words_found": words_found,
                "total_words": words_found,
                "seconds": seconds,
                "hints_used": 0,
                "challenge_date": "2026-09-14",
            },
        )
        assert res.status_code == 200

    await play_daily(token_a, words_found=6, seconds=90)  # lower score
    await play_daily(token_b, words_found=6, seconds=20)  # higher score
    await play_daily(token_stranger, words_found=6, seconds=5)  # not a friend

    board = await client.get(
        "/me/word-search/daily-leaderboard",
        headers={"Authorization": f"Bearer {token_a}"},
        params={"date": "2026-09-14"},
    )
    assert board.status_code == 200
    players = board.json()["players"]
    assert len(players) == 2  # a and b only, not the stranger
    assert players[0]["score"] >= players[1]["score"]
    assert players[0]["placement"] == 1

    for t in (token_a, token_b, token_stranger):
        await _delete_account(client, t, "TestPass123!")


async def test_daily_score_keeps_best_of_repeated_attempts(client):
    token = await _register(client)
    headers = {"Authorization": f"Bearer {token}"}

    async def play(seconds):
        await client.post(
            "/me/activity/complete",
            headers=headers,
            json={
                "activity": "word_search",
                "category": "prophets",
                "difficulty": "easy",
                "words_found": 6,
                "total_words": 6,
                "seconds": seconds,
                "hints_used": 0,
                "challenge_date": "2026-09-15",
            },
        )

    await play(90)  # worse
    await play(10)  # better — should replace
    await play(115)  # worse again — should NOT overwrite the good one

    board = await client.get(
        "/me/word-search/daily-leaderboard",
        headers=headers,
        params={"date": "2026-09-15"},
    )
    players = board.json()["players"]
    assert len(players) == 1
    assert players[0]["seconds"] == 10

    await _delete_account(client, token, "TestPass123!")


async def test_activity_complete_rejects_unknown_activity(client):
    token = await _register(client)

    res = await client.post(
        "/me/activity/complete",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "activity": "not_a_real_activity",
            "difficulty": "easy",
            "words_found": 1,
            "total_words": 1,
            "seconds": 1,
            "hints_used": 0,
        },
    )
    assert res.status_code == 422

    await _delete_account(client, token, "TestPass123!")


async def test_activity_complete_requires_auth(client):
    res = await client.post(
        "/me/activity/complete",
        json={
            "activity": "word_search",
            "difficulty": "easy",
            "words_found": 1,
            "total_words": 1,
            "seconds": 1,
            "hints_used": 0,
        },
    )
    assert res.status_code == 401
