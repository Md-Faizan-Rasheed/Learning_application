"""Proves the multiplayer quiz engine's Socket.IO behavior is byte-for-byte
unchanged for an ordinary (non-campaign) match, despite campaign mode's new
hook points inside find_match/_resolve_round/_end_match.

python-socketio's save_session/get_session/enter_room/emit all assume a real
Engine.IO handshake happened first (they look up an eio_sid for the given
sid). Since this test drives the @sio.event handlers directly as plain
functions — no real transport, no real client — those five methods are
replaced with simple in-memory fakes for the duration of this test. Every
handler is still the exact production code from app/realtime/server.py;
only Socket.IO's own transport plumbing is faked.

Rounds are driven manually (bot answers + round advance) instead of letting
the real timers/random bot delays run, so this test finishes in well under a
second rather than the ~1-2 minutes a real match with 8 rounds would take.
"""

from __future__ import annotations

import uuid

import pytest

from app.realtime import match_store, server
from app.realtime.match_store import ROUNDS_PER_MATCH


class _FakeSio:
    """Minimal in-memory stand-in for the parts of AsyncServer this test
    touches. Not a general-purpose fake — just enough for find_match's and
    _resolve_round's/​_end_match's calls to run without a real transport."""

    def __init__(self):
        self.sessions: dict[str, dict] = {}
        self.rooms: dict[str, set[str]] = {}
        self.emitted: list[tuple[str, dict, dict]] = []

    async def save_session(self, sid, session, namespace=None):
        self.sessions[sid] = session

    async def get_session(self, sid, namespace=None):
        return self.sessions.get(sid, {})

    async def enter_room(self, sid, room, namespace=None):
        self.rooms.setdefault(room, set()).add(sid)

    async def leave_room(self, sid, room, namespace=None):
        self.rooms.get(room, set()).discard(sid)

    async def emit(self, event, data=None, room=None, to=None, **kwargs):
        self.emitted.append((event, data, {"room": room, "to": to}))


@pytest.fixture
def fake_sio(monkeypatch):
    fake = _FakeSio()
    monkeypatch.setattr(server, "sio", fake)
    # Drive rounds manually: skip real bot-answer delays, the deadline
    # watchdog, and the inter-round pause — none of them are what this test
    # is checking, and all three involve real sleeps.
    monkeypatch.setattr(server, "_schedule_bot_answers", _noop)
    monkeypatch.setattr(server, "_deadline_watchdog", _noop)
    monkeypatch.setattr(server, "_advance_after_pause", _noop)
    return fake


async def _noop(*args, **kwargs):
    return None


async def _virgin_stage_and_event(db) -> tuple[str, str]:
    """A campaign stage with no linked events, paired with a Seerah event
    with no tagged questions — lets a test build an exactly-sized, fully
    isolated question pool without depending on (or disturbing) whatever
    stages/events/tagging this DB happens to be seeded with right now."""
    from sqlalchemy import text

    stage_row = (
        await db.execute(
            text(
                """
                SELECT cs.slug FROM campaign_stages cs
                WHERE NOT EXISTS (
                    SELECT 1 FROM event_framework_tags eft
                    WHERE eft.tag_value = cs.slug AND eft.framework = 'movement_stage'
                )
                LIMIT 1
                """
            )
        )
    ).first()
    assert stage_row, "need at least one campaign_stage with no linked events for this test"

    event_row = (
        await db.execute(
            text(
                "SELECT se.id FROM seerah_events se "
                "WHERE NOT EXISTS (SELECT 1 FROM questions q WHERE q.event_id = se.id) LIMIT 1"
            )
        )
    ).first()
    assert event_row, "need at least one seerah_event with no questions tagged to it for this test"
    return stage_row[0], str(event_row[0])


async def test_ordinary_match_emits_the_exact_same_event_sequence_as_before(fake_sio):
    sid = f"test-sid-{uuid.uuid4().hex[:8]}"

    # connect(): guest, no auth token — same as every unauthenticated player today.
    await server.connect(sid, environ={}, auth=None)

    # find_match(): no stage_slug — the exact payload shape every existing
    # client call site sends today.
    result = await server.find_match(
        sid, {"name": "PytestPlayer", "difficulty": "easy", "category": "seerah"}
    )
    assert result["ok"] is True
    match_id = result["match_id"]
    human_seat = result["seat"]

    # A quick-match lobby waits for more humans; drive it forward exactly
    # like the real 8-second timer eventually would (fill_bots=True), but
    # synchronously. The real timer path also retires this (category,
    # difficulty)'s open-lobby pointer before starting — replicate that so a
    # completed match here doesn't get "rejoined" as an open lobby by the
    # next run of this same test (Redis persists across test runs; without
    # this, the next run would attach to this match instead of a fresh one).
    await match_store.clear_open_match("easy", match_id, "seerah")
    await server._begin_match(match_id, "easy", fill_bots=True)

    rnd = await match_store.get_round(match_id)
    assert rnd is not None, "no live question was available — is the DB seeded?"

    for round_no in range(ROUNDS_PER_MATCH):
        players = await match_store.get_players(match_id)
        rnd = await match_store.get_round(match_id)
        assert rnd["round_no"] == round_no
        correct = rnd["correct_index"]

        for p in players:
            chosen = correct if p["seat"] == human_seat else correct  # everyone answers correctly
            await server._handle_answer(
                match_id, round_no, p["seat"], chosen, 1000, is_bot=p["is_bot"]
            )
        # The last _handle_answer call above resolves the round synchronously
        # (and, on the final round, ends the match synchronously too).

        if round_no < ROUNDS_PER_MATCH - 1:
            await server._start_and_broadcast_question(
                match_id, difficulty="easy", index=round_no + 1
            )

    names = [event for event, _, _ in fake_sio.emitted]

    expected = ["server_hello", "roster", "roster", "match_started"]
    for _ in range(ROUNDS_PER_MATCH):
        expected.append("question")
        expected += ["player_answered"] * 4
        expected.append("round_result")
    expected.append("match_over")

    assert names == expected, (
        "the Socket.IO event sequence for an ordinary match changed — "
        "campaign mode's hook points must be a no-op here"
    )

    # Belt and suspenders: the two new campaign events must never appear at
    # all for a match with no campaign_stage_id.
    assert "stage_momentum" not in names
    assert "campaign_progress" not in names

    # And the durable record confirms campaign_stage_id really was left null.
    assert await match_store.get_campaign_stage(match_id) is None


async def test_campaign_match_emits_momentum_and_progress_events(fake_sio):
    """The other half of the same proof: when a match DOES carry a
    campaign_stage_id, the new hook points actually fire — not just that
    they stay silent for ordinary matches.

    Rather than assuming any particular stage/event is already tagged with
    enough real questions (this DB's seed content changes independently of
    this test), this picks a stage+event pair with no existing links (see
    _virgin_stage_and_event) and borrows real untagged questions onto it
    for the test's duration, undoing both in `finally`.
    """
    from sqlalchemy import text

    from app.campaign import repository as campaign_repo
    from app.db import SessionLocal

    # Tag enough questions to survive get_recent_questions' no-repeats
    # filter across all 8 rounds — one question alone would starve after
    # round 1 (it becomes its own only "recently used" exclusion).
    async with SessionLocal() as db:
        stage_slug, event_id = await _virgin_stage_and_event(db)
        await campaign_repo.set_event_stage_tag(db, event_id=event_id, stage_slug=stage_slug)
        tagged_question_ids = [
            row[0]
            for row in (
                await db.execute(
                    text(
                        """
                        SELECT q.id FROM questions q JOIN categories c ON c.id = q.category_id
                        WHERE c.slug = 'seerah' AND q.review_state = 'live'
                          AND q.event_id IS NULL
                        LIMIT 10
                        """
                    )
                )
            ).all()
        ]
        assert len(tagged_question_ids) >= ROUNDS_PER_MATCH, (
            "not enough live 'seerah'/'easy' questions in this DB to run this test"
        )
        for qid in tagged_question_ids:
            await db.execute(
                text("UPDATE questions SET event_id = :e WHERE id = :q"),
                {"e": event_id, "q": str(qid)},
            )
        await db.commit()

    sid = f"test-sid-{uuid.uuid4().hex[:8]}"
    try:
        await _run_campaign_match(fake_sio, sid, stage_slug)
    finally:
        async with SessionLocal() as db:
            for qid in tagged_question_ids:
                await db.execute(
                    text("UPDATE questions SET event_id = NULL WHERE id = :q"),
                    {"q": str(qid)},
                )
            await campaign_repo.set_event_stage_tag(db, event_id=event_id, stage_slug=None)
            await db.commit()


async def _run_campaign_match(fake_sio, sid, stage_slug):
    from app.campaign import repository as campaign_repo
    from app.db import SessionLocal

    await server.connect(sid, environ={}, auth=None)

    result = await server.find_match(
        sid,
        {
            "name": "PytestCampaignPlayer",
            "difficulty": "easy",
            "category": "seerah",
            "stage_slug": stage_slug,
        },
    )
    assert result["ok"] is True
    match_id = result["match_id"]
    human_seat = result["seat"]
    human_user_id = result["user_id"]

    await match_store.clear_open_match("easy", match_id, "seerah", stage_slug)
    await server._begin_match(match_id, "easy", fill_bots=True)

    assert await match_store.get_campaign_stage(match_id) is not None

    for round_no in range(ROUNDS_PER_MATCH):
        players = await match_store.get_players(match_id)
        rnd = await match_store.get_round(match_id)
        correct = rnd["correct_index"]
        for p in players:
            await server._handle_answer(
                match_id, round_no, p["seat"], correct, 1000, is_bot=p["is_bot"]
            )
        if round_no < ROUNDS_PER_MATCH - 1:
            await server._start_and_broadcast_question(
                match_id, difficulty="easy", index=round_no + 1
            )

    momentum_events = [
        (data, kwargs) for name, data, kwargs in fake_sio.emitted if name == "stage_momentum"
    ]
    assert len(momentum_events) == ROUNDS_PER_MATCH, (
        "expected one stage_momentum event per round"
    )
    # Every round answered correctly: momentum climbs by
    # CAMPAIGN_MOMENTUM_PER_CORRECT each time (capped at 100), streak climbs
    # by 1 each time, and both are broadcast to the whole room.
    for i, (data, kwargs) in enumerate(momentum_events, start=1):
        assert data["momentum"] == min(server.CAMPAIGN_MOMENTUM_PER_CORRECT * i, 100)
        assert data["streak"] == i
        assert kwargs["room"] == match_id

    progress_events = [
        (data, kwargs) for name, data, kwargs in fake_sio.emitted if name == "campaign_progress"
    ]
    assert len(progress_events) == 1, "expected exactly one campaign_progress event"
    progress_data, progress_kwargs = progress_events[0]
    assert progress_kwargs["to"] == sid, "campaign_progress must go to the player only, not the room"
    # A perfect 8-round match now clears the stage in one go: 8 *
    # CAMPAIGN_MOMENTUM_PER_CORRECT (104) is capped at the 100 target.
    assert progress_data["progress"] == 100
    assert progress_data["completed"] is True

    # And it's durably persisted, not just broadcast.
    async with SessionLocal() as db:
        stage_id = await campaign_repo.get_stage_id_by_slug(db, stage_slug)
        stages = await campaign_repo.get_stages_for_user(db, human_user_id)
    stage_row = next(s for s in stages if str(s["id"]) == stage_id)
    assert stage_row["progress"] == 100


async def test_campaign_stage_completes_despite_a_small_question_pool_and_wrong_answers(fake_sio):
    """Unlocking a stage now means finishing its match, any score — not a
    momentum threshold (see campaign_repo.complete_stage). Rather than
    assuming some stage in this DB happens to have a naturally small tagged
    pool, this builds one deliberately: a virgin stage+event pair (see
    _virgin_stage_and_event) given exactly _SMALL_POOL_SIZE questions,
    fewer than ROUNDS_PER_MATCH (8). This proves two things at once: the
    repeat-fallback in _start_and_broadcast_question lets the match reach
    all 8 rounds despite the small pool, and answering every round wrong
    still completes the stage."""
    from sqlalchemy import text

    from app.campaign import repository as campaign_repo
    from app.db import SessionLocal

    _SMALL_POOL_SIZE = 3

    async with SessionLocal() as db:
        stage_slug, event_id = await _virgin_stage_and_event(db)
        await campaign_repo.set_event_stage_tag(db, event_id=event_id, stage_slug=stage_slug)
        borrowed_ids = [
            row[0]
            for row in (
                await db.execute(
                    text(
                        """
                        SELECT q.id FROM questions q JOIN categories c ON c.id = q.category_id
                        WHERE c.slug = 'seerah' AND q.review_state = 'live' AND q.event_id IS NULL
                        LIMIT :n
                        """
                    ),
                    {"n": _SMALL_POOL_SIZE},
                )
            ).all()
        ]
        assert len(borrowed_ids) == _SMALL_POOL_SIZE, (
            "not enough live untagged 'seerah' questions in this DB to run this test"
        )
        for qid in borrowed_ids:
            await db.execute(
                text("UPDATE questions SET event_id = :e WHERE id = :q"),
                {"e": event_id, "q": str(qid)},
            )
        await db.commit()

    try:
        sid = f"test-sid-{uuid.uuid4().hex[:8]}"
        await server.connect(sid, environ={}, auth=None)

        result = await server.find_match(
            sid,
            {
                "name": "PytestWrongAnswerPlayer",
                "difficulty": "easy",
                "category": "seerah",
                "stage_slug": stage_slug,
            },
        )
        assert result["ok"] is True
        match_id = result["match_id"]

        await match_store.clear_open_match("easy", match_id, "seerah", stage_slug)
        await server._begin_match(match_id, "easy", fill_bots=True)

        for round_no in range(ROUNDS_PER_MATCH):
            players = await match_store.get_players(match_id)
            rnd = await match_store.get_round(match_id)
            assert rnd is not None, (
                "round should never come back empty — the repeat-fallback must "
                "kick in once this stage's small question pool is exhausted"
            )
            correct = rnd["correct_index"]
            wrong = (correct + 1) % len(rnd["options"]["en"])
            for p in players:
                await server._handle_answer(
                    match_id, round_no, p["seat"], wrong, 1000, is_bot=p["is_bot"]
                )
            if round_no < ROUNDS_PER_MATCH - 1:
                await server._start_and_broadcast_question(
                    match_id, difficulty="easy", index=round_no + 1
                )

        names = [event for event, _, _ in fake_sio.emitted]
        assert "match_over" in names, "the match must reach its natural end despite the small pool"
        assert "no_questions" not in names

        progress_events = [
            (data, kwargs) for name, data, kwargs in fake_sio.emitted if name == "campaign_progress"
        ]
        assert len(progress_events) == 1
        progress_data, _ = progress_events[0]
        assert progress_data["progress"] == 100
        assert progress_data["completed"] is True, (
            "any finished match completes the stage, regardless of score"
        )
    finally:
        async with SessionLocal() as db:
            for qid in borrowed_ids:
                await db.execute(
                    text("UPDATE questions SET event_id = NULL WHERE id = :q"),
                    {"q": str(qid)},
                )
            await campaign_repo.set_event_stage_tag(db, event_id=event_id, stage_slug=None)
            await db.commit()
