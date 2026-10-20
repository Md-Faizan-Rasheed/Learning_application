from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from ..common.deps import get_db
from ..common.rate_limit import rate_limit
from ..redis_client import redis_client
from . import repository as repo
from .schemas import AnswerIn, AnswerResult, ServedQuestion
from .scoring import QUESTION_TIME_MS, score_answer

router = APIRouter(prefix="/play", tags=["play"])

LANGS = ("en", "ur", "ar")
_ANONYMOUS_QUESTION_LIMIT = 20
_ANONYMOUS_ANSWER_LIMIT = 60
_ANONYMOUS_PLAY_WINDOW_SECONDS = 60
_PRACTICE_SESSION_TTL_SECONDS = 30 * 60


def _client_ip(request: Request) -> str:
    return request.client.host if request.client else "unknown"


def _practice_session_key(match_id: str, question_id: str) -> str:
    return f"anonymous-practice:{match_id}:{question_id}"


@router.get("/practice/question", response_model=ServedQuestion)
async def serve_practice_question(
    request: Request,
    lang: str = Query("en"),
    difficulty: str | None = Query(None),
    db: AsyncSession = Depends(get_db),
) -> ServedQuestion:
    """Start an anonymous practice round with short-lived server validation.

    No account, match row, or attempt row is created for the player. The
    question-to-random-match binding expires from Redis after 30 minutes.
    The correct answer is deliberately NOT included in this response.
    """
    await rate_limit(
        key=f"play-question:{_client_ip(request)}",
        limit=_ANONYMOUS_QUESTION_LIMIT,
        window_seconds=_ANONYMOUS_PLAY_WINDOW_SECONDS,
    )
    if lang not in LANGS:
        raise HTTPException(status_code=422, detail=f"lang must be one of {LANGS}")

    q = await repo.pick_live_question(db, difficulty)
    if q is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="no live questions available (add one and promote it to 'live')",
        )

    match_id = str(uuid.uuid4())
    await redis_client.set(
        _practice_session_key(match_id, str(q["id"])),
        "issued",
        ex=_PRACTICE_SESSION_TTL_SECONDS,
    )
    options = q["options"].get(lang) or q["options"]["en"]
    prompt = q["prompt"].get(lang) or q["prompt"]["en"]

    return ServedQuestion(
        question_id=q["id"],
        match_id=match_id,
        difficulty=q["difficulty"],
        lang=lang,
        prompt=prompt,
        options=options,
        time_ms=QUESTION_TIME_MS,
    )


@router.post("/answer", response_model=AnswerResult)
async def submit_answer(
    data: AnswerIn,
    request: Request,
    db: AsyncSession = Depends(get_db),
) -> AnswerResult:
    """Judge the answer on the server and cache the result briefly for retries.

    Answer correctness and score are computed here, never trusted from the
    client. No user-linked attempt or progress data is written to Postgres.
    """
    await rate_limit(
        key=f"play-answer:{_client_ip(request)}",
        limit=_ANONYMOUS_ANSWER_LIMIT,
        window_seconds=_ANONYMOUS_PLAY_WINDOW_SECONDS,
    )
    session_key = _practice_session_key(str(data.match_id), str(data.question_id))
    cached_result = await redis_client.get(f"{session_key}:result")
    if cached_result is not None:
        return AnswerResult.model_validate_json(cached_result)

    if await redis_client.get(session_key) != "issued":
        raise HTTPException(status_code=404, detail="practice question expired or not found")

    q = await repo.get_question_for_grading(db, data.question_id)
    if q is None:
        raise HTTPException(status_code=404, detail="question not found or not live")

    n_options = len(q["options"]["en"])

    # Validate the chosen index (a bad index just means "wrong", not a crash).
    chosen_index = data.chosen_index
    is_correct = chosen_index is not None and chosen_index == q["correct_index"]
    if chosen_index is not None and (chosen_index < 0 or chosen_index >= n_options):
        is_correct = False

    points = score_answer(
        difficulty=q["difficulty"],
        is_correct=is_correct,
        response_ms=data.response_ms,
    )

    result = AnswerResult(
        is_correct=is_correct,
        correct_index=q["correct_index"],
        points_awarded=points,
        correct_option=q["options"]["en"][q["correct_index"]],
    )
    result_key = f"{session_key}:result"
    await redis_client.set(
        result_key,
        result.model_dump_json(),
        ex=_PRACTICE_SESSION_TTL_SECONDS,
        nx=True,
    )
    # Keep a concurrent retry idempotent: return the result that won the
    # atomic Redis write if another answer arrived at the same time.
    stored_result = await redis_client.get(result_key)
    return AnswerResult.model_validate_json(stored_result or result.model_dump_json())
