from __future__ import annotations

from unittest.mock import AsyncMock

import pytest

from app.realtime import match_store, server
from app.game import repository as game_repo


class _FakeSession:
    async def __aenter__(self):
        return self

    async def __aexit__(self, *_args):
        return None

    async def commit(self):
        return None


class _FakeSio:
    async def get_session(self, _sid):
        return {}

    async def enter_room(self, _sid, _room):
        return None


def _mock_campaign_catalog(monkeypatch, *, available: int):
    monkeypatch.setattr(server, "SessionLocal", _FakeSession)
    monkeypatch.setattr(
        server.campaign_repo, "get_stage_id_by_slug", AsyncMock(return_value="stage-id")
    )
    monkeypatch.setattr(
        server.campaign_repo,
        "get_stage_question_count",
        AsyncMock(return_value=available),
    )


@pytest.mark.asyncio
async def test_campaign_match_uses_selected_question_count(monkeypatch):
    _mock_campaign_catalog(monkeypatch, available=12)
    monkeypatch.setattr(server, "sio", _FakeSio())
    monkeypatch.setattr(server, "_broadcast_roster", AsyncMock())
    begin_match = AsyncMock()
    monkeypatch.setattr(server, "_begin_match", begin_match)

    monkeypatch.setattr(server.game_repo, "create_db_match", AsyncMock(return_value="match-id"))
    monkeypatch.setattr(server.game_repo, "create_db_user", AsyncMock(return_value="user-id"))
    monkeypatch.setattr(server.game_repo, "add_match_player", AsyncMock())
    monkeypatch.setattr(match_store, "find_open_match", AsyncMock(return_value=None))
    create_match = AsyncMock(return_value="match-id")
    monkeypatch.setattr(match_store, "create_match", create_match)
    set_open_match = AsyncMock()
    monkeypatch.setattr(match_store, "set_open_match", set_open_match)
    find_open_match = AsyncMock()
    monkeypatch.setattr(match_store, "find_open_match", find_open_match)
    monkeypatch.setattr(
        match_store,
        "add_player",
        AsyncMock(return_value={"seat": 0}),
    )
    monkeypatch.setattr(match_store, "count_humans", AsyncMock(return_value=1))

    result = await server.find_match(
        "test-sid",
        {
            "name": "Campaign tester",
            "category": "seerah",
            "stage_slug": "stage-one",
            "question_start": 5,
            "question_end": 7,
        },
    )

    assert result["ok"] is True
    assert create_match.await_args.kwargs["rounds_total"] == 3
    assert create_match.await_args.kwargs["campaign_question_start"] == 5
    assert create_match.await_args.kwargs["campaign_question_end"] == 7
    find_open_match.assert_not_awaited()
    set_open_match.assert_not_awaited()
    begin_match.assert_awaited_once_with("match-id", "easy")


@pytest.mark.asyncio
async def test_campaign_match_rejects_count_above_available_questions(monkeypatch):
    _mock_campaign_catalog(monkeypatch, available=4)
    find_open_match = AsyncMock()
    monkeypatch.setattr(match_store, "find_open_match", find_open_match)

    result = await server.find_match(
        "test-sid",
        {"name": "Campaign tester", "stage_slug": "stage-one", "question_start": 2, "question_end": 5},
    )

    assert result == {
        "ok": False,
        "error": "invalid_question_range",
        "available_question_count": 4,
    }
    find_open_match.assert_not_awaited()


@pytest.mark.asyncio
async def test_campaign_room_creation_is_rejected(monkeypatch):
    monkeypatch.setattr(server, "sio", _FakeSio())
    result = await server.create_room(
        "test-sid", {"name": "Campaign tester", "stage_slug": "stage-one"}
    )

    assert result == {"ok": False, "error": "campaign matches are bot-only"}


@pytest.mark.asyncio
async def test_campaign_room_join_is_rejected(monkeypatch):
    monkeypatch.setattr(match_store, "match_id_for_room_code", AsyncMock(return_value="match-id"))
    monkeypatch.setattr(
        match_store,
        "get_meta",
        AsyncMock(return_value={"status": "waiting", "campaign_stage_id": "stage-id"}),
    )

    result = await server.join_room("test-sid", {"name": "Another human", "room_code": "ABC123"})

    assert result == {"ok": False, "error": "campaign matches are bot-only"}


class _FakeResult:
    def mappings(self):
        return self

    def first(self):
        return {"id": "question-id"}


class _FakeDb:
    def __init__(self):
        self.clause = None
        self.params = None

    async def execute(self, clause, params):
        self.clause = str(clause)
        self.params = params
        return _FakeResult()


@pytest.mark.asyncio
async def test_question_picker_limits_queries_to_the_selected_stage_range():
    db = _FakeDb()

    result = await game_repo.pick_live_question(
        db,
        None,
        "seerah",
        [],
        stage_slug="stage-one",
        stage_question_start=12,
        stage_question_end=20,
    )

    assert result == {"id": "question-id"}
    assert "row_number() OVER (ORDER BY q.created_at, q.id)" in db.clause
    assert "question_no BETWEEN :question_start AND :question_end" in db.clause
    assert db.params["question_start"] == 12
    assert db.params["question_end"] == 20
