from __future__ import annotations

import uuid

import pytest
from fastapi import HTTPException, Request

from app.game import repository as game_repo
from app.game import routes as game_routes
from app.game.schemas import AnswerIn


def _request(path: str = "/play") -> Request:
    return Request(
        {
            "type": "http",
            "asgi": {"version": "3.0"},
            "http_version": "1.1",
            "method": "POST",
            "scheme": "http",
            "path": path,
            "raw_path": path.encode(),
            "query_string": b"",
            "headers": [],
            "client": ("198.51.100.24", 4567),
            "server": ("test", 80),
        }
    )


class _FakeResult:
    def mappings(self) -> _FakeResult:
        return self

    def first(self):
        return None


class _FakeDb:
    def __init__(self) -> None:
        self.statements: list[str] = []

    async def execute(self, statement, *args, **kwargs):
        self.statements.append(str(statement))
        return _FakeResult()


class _FakeRedis:
    def __init__(self) -> None:
        self.values: dict[str, str] = {}

    async def get(self, key: str) -> str | None:
        return self.values.get(key)

    async def set(self, key: str, value: str, *, ex: int, nx: bool = False):
        if nx and key in self.values:
            return False
        self.values[key] = value
        return True


@pytest.mark.asyncio
async def test_anonymous_practice_routes_apply_ip_limits(monkeypatch):
    calls: list[dict] = []

    async def capture_limit(**kwargs):
        calls.append(kwargs)

    monkeypatch.setattr(game_routes, "rate_limit", capture_limit)
    fake_redis = _FakeRedis()
    monkeypatch.setattr(game_routes, "redis_client", fake_redis)
    question_id = uuid.uuid4()
    monkeypatch.setattr(
        game_routes.repo,
        "pick_live_question",
        lambda *args, **kwargs: _async_value(
            {
                "id": question_id,
                "difficulty": "easy",
                "prompt": {"en": "Question"},
                "options": {"en": ["A", "B"]},
                "correct_index": 1,
            }
        ),
    )

    served = await game_routes.serve_practice_question(
        request=_request("/play/practice/question"),
        lang="en",
        difficulty=None,
        db=object(),
    )
    session_key = game_routes._practice_session_key(str(served.match_id), str(question_id))
    assert fake_redis.values[session_key] == "issued"

    monkeypatch.setattr(
        game_routes.repo,
        "get_question_for_grading",
        lambda *args: _async_value(
            {
                "difficulty": "easy",
                "options": {"en": ["A", "B"]},
                "correct_index": 1,
            }
        ),
    )
    answer_data = AnswerIn(
        question_id=question_id,
        match_id=served.match_id,
        chosen_index=1,
        response_ms=1000,
    )
    first_answer = await game_routes.submit_answer(
        data=answer_data,
        request=_request("/play/answer"),
        db=object(),
    )
    retry = await game_routes.submit_answer(
        data=answer_data.model_copy(update={"chosen_index": 0}),
        request=_request("/play/answer"),
        db=object(),
    )
    assert retry == first_answer
    assert len(fake_redis.values) == 2

    assert calls == [
        {"key": "play-question:198.51.100.24", "limit": 20, "window_seconds": 60},
        {"key": "play-answer:198.51.100.24", "limit": 60, "window_seconds": 60},
        {"key": "play-answer:198.51.100.24", "limit": 60, "window_seconds": 60},
    ]


async def _async_value(value):
    return value


@pytest.mark.asyncio
async def test_anonymous_question_queries_exclude_teacher_private_questions():
    db = _FakeDb()
    await game_repo.pick_live_question(db, "easy", "seerah")
    assert "q.is_private = FALSE" in db.statements[0]

    db = _FakeDb()
    await game_repo.pick_live_question(
        db,
        None,
        "seerah",
        stage_slug="hijrah_relocation",
        stage_question_start=1,
        stage_question_end=10,
    )
    assert "q.is_private = FALSE" in db.statements[0]

    db = _FakeDb()
    await game_repo.get_question_for_grading(db, uuid.uuid4())
    assert "is_private = FALSE" in db.statements[0]
