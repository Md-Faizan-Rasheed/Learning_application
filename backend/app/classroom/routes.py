from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from ..common.deps import CurrentUser, get_current_user, get_db
from ..game.scoring import score_answer
from . import repository as repo
from .schemas import (
    AnswerIn,
    AnswerResult,
    AssignedQuizOut,
    JoinIn,
    JoinOut,
    QuizResultOut,
    ServedQuizQuestion,
    SUPPORTED_LANGS,
)

router = APIRouter(prefix="/classroom", tags=["classroom"])


@router.post("/join", response_model=JoinOut)
async def join_class(
    data: JoinIn,
    current: CurrentUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    if current.role == "teacher":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="teachers cannot join classes")
    result = await repo.join_class(db, current.user_id, data.join_code)
    if result is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="invalid join code")
    return result


@router.get("/quizzes", response_model=list[AssignedQuizOut])
async def list_assigned_quizzes(
    current: CurrentUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[dict]:
    return await repo.list_assigned_quizzes(db, current.user_id)


@router.get("/quizzes/{quiz_id}/start", response_model=ServedQuizQuestion)
async def start_quiz(
    quiz_id: UUID,
    lang: str = Query("en"),
    current: CurrentUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ServedQuizQuestion:
    if lang not in SUPPORTED_LANGS:
        raise HTTPException(status_code=422, detail=f"lang must be one of {SUPPORTED_LANGS}")

    quiz = await repo.get_published_quiz_for_student(db, current.user_id, quiz_id)
    if quiz is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="quiz not found")

    attempt = await repo.get_or_create_attempt(db, current.user_id, quiz_id, quiz["total_questions"])
    if attempt["status"] == "completed":
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="quiz already completed")

    next_q = await repo.get_next_question(db, quiz_id, attempt["id"], lang)
    if next_q is None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="quiz already completed")

    return ServedQuizQuestion(
        quiz_id=quiz_id,
        question_id=next_q["question_id"],
        lang=lang,
        prompt=next_q["prompt"],
        options=next_q["options"],
        time_limit_ms=quiz["time_limit_ms"],
        question_no=next_q["order_no"] + 1,
        total_questions=quiz["total_questions"],
    )


@router.post("/quizzes/{quiz_id}/answer", response_model=AnswerResult)
async def answer_quiz_question(
    quiz_id: UUID,
    data: AnswerIn,
    current: CurrentUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> AnswerResult:
    quiz = await repo.get_published_quiz_for_student(db, current.user_id, quiz_id)
    if quiz is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="quiz not found")

    attempt = await repo.get_or_create_attempt(db, current.user_id, quiz_id, quiz["total_questions"])

    q = await repo.question_in_quiz(db, quiz_id, data.question_id)
    if q is None:
        raise HTTPException(status_code=404, detail="question not part of this quiz")
    n_options = len(q["options"]["en"])

    # Idempotency: if already answered, return the stored result unchanged.
    existing = await repo.get_existing_answer(db, attempt["id"], data.question_id)
    if existing is not None:
        return AnswerResult(
            is_correct=existing["is_correct"],
            correct_index=q["correct_index"],
            points_awarded=existing["points_awarded"],
            correct_option=q["options"]["en"][q["correct_index"]],
            quiz_complete=attempt["status"] == "completed",
        )

    chosen_index = data.chosen_index
    is_correct = chosen_index is not None and chosen_index == q["correct_index"]
    if chosen_index is not None and (chosen_index < 0 or chosen_index >= n_options):
        is_correct = False

    points = score_answer(difficulty=q["difficulty"], is_correct=is_correct, response_ms=data.response_ms)

    quiz_complete = await repo.record_answer(
        db,
        attempt_id=attempt["id"],
        question_id=data.question_id,
        chosen_index=chosen_index,
        is_correct=is_correct,
        points_awarded=points,
    )

    return AnswerResult(
        is_correct=is_correct,
        correct_index=q["correct_index"],
        points_awarded=points,
        correct_option=q["options"]["en"][q["correct_index"]],
        quiz_complete=quiz_complete,
    )


@router.get("/quizzes/{quiz_id}/result", response_model=QuizResultOut)
async def get_quiz_result(
    quiz_id: UUID,
    current: CurrentUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    result = await repo.get_result(db, current.user_id, quiz_id)
    if result is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="no completed attempt for this quiz")
    return {"quiz_id": quiz_id, **result}
