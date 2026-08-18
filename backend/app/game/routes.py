from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from ..common.deps import get_db
from . import repository as repo
from .schemas import AnswerIn, AnswerResult, ServedQuestion
from .scoring import QUESTION_TIME_MS, score_answer

router = APIRouter(prefix="/play", tags=["play"])

LANGS = ("en", "ur", "ar")


@router.get("/practice/question", response_model=ServedQuestion)
async def serve_practice_question(
    lang: str = Query("en"),
    difficulty: str | None = Query(None),
    db: AsyncSession = Depends(get_db),
) -> ServedQuestion:
    """Start a practice round: create a solo match and serve one LIVE question
    in the player's language. The correct answer is deliberately NOT included."""
    if lang not in LANGS:
        raise HTTPException(status_code=422, detail=f"lang must be one of {LANGS}")

    q = await repo.pick_live_question(db, difficulty)
    if q is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="no live questions available (add one and promote it to 'live')",
        )

    match_id = await repo.create_practice_match(db, q["difficulty"])
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
async def submit_answer(data: AnswerIn, db: AsyncSession = Depends(get_db)) -> AnswerResult:
    """Judge an answer on the SERVER. Correctness and score are computed here,
    never trusted from the client. Idempotent: re-submitting the same answer
    returns the original result and never double-records."""
    q = await repo.get_question_for_grading(db, data.question_id)
    if q is None:
        raise HTTPException(status_code=404, detail="question not found or not live")

    user_id = await repo.get_or_create_practice_user(db)
    n_options = len(q["options"]["en"])

    # Idempotency: if already answered, return the stored result unchanged.
    existing = await repo.get_existing_attempt(db, data.match_id, data.question_id, user_id)
    if existing is not None:
        correct_index = q["correct_index"]
        return AnswerResult(
            is_correct=existing["is_correct"],
            correct_index=correct_index,
            points_awarded=existing["points_awarded"],
            correct_option=q["options"]["en"][correct_index],
        )

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

    chosen_answer = (
        q["options"]["en"][chosen_index]
        if chosen_index is not None and 0 <= chosen_index < n_options
        else None
    )

    await repo.insert_attempt(
        db,
        match_id=data.match_id,
        question_id=data.question_id,
        user_id=user_id,
        chosen_answer=chosen_answer,
        is_correct=is_correct,
        response_ms=data.response_ms,
        points_awarded=points,
    )

    return AnswerResult(
        is_correct=is_correct,
        correct_index=q["correct_index"],
        points_awarded=points,
        correct_option=q["options"]["en"][q["correct_index"]],
    )