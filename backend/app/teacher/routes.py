from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from ..common.deps import CurrentUser, get_db, require_teacher_user
from ..config import settings
from ..content.repository import category_exists, list_categories
from . import ai_import, repository as repo
from .schemas import (
    AiImportRequest,
    AiImportResult,
    AiQuestionOut,
    BankQuestionOut,
    CategoryOut,
    ClassCreate,
    ClassDetailOut,
    ClassOut,
    QuizCreate,
    QuizOut,
    QuizResultsOut,
    TeacherQuestionCreate,
    TeacherQuestionOut,
)

# Teacher-only: every route here requires a real JWT with role == 'teacher'.
# require_teacher_user is depended on per-route (not router-level) because
# every handler also needs the resulting CurrentUser to scope queries to
# "this teacher's own" classes/questions/quizzes.
router = APIRouter(prefix="/teacher", tags=["teacher"])


@router.post("/classes", response_model=ClassOut, status_code=status.HTTP_201_CREATED)
async def create_class(
    data: ClassCreate,
    current: CurrentUser = Depends(require_teacher_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    return await repo.create_class(db, teacher_id=current.user_id, name=data.name)


@router.get("/classes", response_model=list[ClassOut])
async def list_classes(
    current: CurrentUser = Depends(require_teacher_user),
    db: AsyncSession = Depends(get_db),
) -> list[dict]:
    return await repo.list_classes(db, current.user_id)


@router.get("/classes/{class_id}", response_model=ClassDetailOut)
async def get_class(
    class_id: UUID,
    current: CurrentUser = Depends(require_teacher_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    cls = await repo.get_class(db, current.user_id, class_id)
    if cls is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="class not found")
    return cls


@router.delete("/classes/{class_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_class(
    class_id: UUID,
    current: CurrentUser = Depends(require_teacher_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    deleted = await repo.delete_class(db, current.user_id, class_id)
    if not deleted:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="class not found")


@router.get("/categories", response_model=list[CategoryOut])
async def list_active_categories(
    current: CurrentUser = Depends(require_teacher_user),
    db: AsyncSession = Depends(get_db),
) -> list[dict]:
    """Active categories, for the category picker when authoring a question."""
    return await list_categories(db, active_only=True)


@router.post("/questions", response_model=TeacherQuestionOut, status_code=status.HTTP_201_CREATED)
async def create_question(
    data: TeacherQuestionCreate,
    current: CurrentUser = Depends(require_teacher_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    if not await category_exists(db, data.category_id):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="category_id does not exist")
    return await repo.create_teacher_question(db, current.user_id, data)


@router.get("/questions", response_model=list[TeacherQuestionOut])
async def list_questions(
    current: CurrentUser = Depends(require_teacher_user),
    db: AsyncSession = Depends(get_db),
) -> list[dict]:
    return await repo.list_teacher_questions(db, current.user_id)


@router.post("/questions/ai-import", response_model=AiImportResult)
async def ai_import_questions(
    data: AiImportRequest,
    current: CurrentUser = Depends(require_teacher_user),
    db: AsyncSession = Depends(get_db),
) -> AiImportResult:
    if not settings.openai_api_key:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="AI import is not configured")
    if not await category_exists(db, data.category_id):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="category_id does not exist")
    try:
        extracted = await ai_import.extract_questions(data.text)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(e))

    created = []
    for q in extracted:
        row = await repo.create_ai_question(
            db,
            teacher_id=current.user_id,
            category_id=data.category_id,
            prompt=q.prompt,
            options=q.options,
            correct_index=q.correct_index,
        )
        created.append(AiQuestionOut(**row, note=q.note))
    return AiImportResult(questions=created)


@router.post("/questions/{question_id}/confirm", response_model=TeacherQuestionOut)
async def confirm_question(
    question_id: UUID,
    current: CurrentUser = Depends(require_teacher_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    row = await repo.confirm_question(db, teacher_id=current.user_id, question_id=question_id)
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="question not found, not yours, or already confirmed",
        )
    return row


@router.get("/bank-questions", response_model=list[BankQuestionOut])
async def list_bank_questions(
    category_id: UUID | None = Query(None),
    difficulty: str | None = Query(None),
    current: CurrentUser = Depends(require_teacher_user),
    db: AsyncSession = Depends(get_db),
) -> list[dict]:
    """Browse the public live question bank to pick from when building a quiz."""
    return await repo.list_bank_questions(db, category_id, difficulty)


@router.post("/quizzes", response_model=QuizOut, status_code=status.HTTP_201_CREATED)
async def create_quiz(
    data: QuizCreate,
    current: CurrentUser = Depends(require_teacher_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    if not await repo.class_belongs_to_teacher(db, current.user_id, data.class_id):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="class not found")
    if not await repo.question_ids_usable_by_teacher(db, current.user_id, data.question_ids):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="one or more question_ids are invalid or not usable by this teacher",
        )
    return await repo.create_quiz(db, current.user_id, data)


@router.post("/quizzes/{quiz_id}/publish", response_model=QuizOut)
async def publish_quiz(
    quiz_id: UUID,
    current: CurrentUser = Depends(require_teacher_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    pending = await repo.quiz_has_unconfirmed_drafts(db, current.user_id, quiz_id)
    if pending:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"{pending} question(s) still need review before this quiz can be published",
        )
    quiz = await repo.publish_quiz(db, current.user_id, quiz_id)
    if quiz is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="quiz not found, not owned by you, or not in draft status",
        )
    return quiz


@router.get("/quizzes", response_model=list[QuizOut])
async def list_quizzes(
    current: CurrentUser = Depends(require_teacher_user),
    db: AsyncSession = Depends(get_db),
) -> list[dict]:
    return await repo.list_quizzes(db, current.user_id)


@router.get("/quizzes/{quiz_id}", response_model=QuizOut)
async def get_quiz(
    quiz_id: UUID,
    current: CurrentUser = Depends(require_teacher_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    quiz = await repo.get_quiz_owned(db, current.user_id, quiz_id)
    if quiz is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="quiz not found")
    return quiz


@router.get("/quizzes/{quiz_id}/results", response_model=QuizResultsOut)
async def get_quiz_results(
    quiz_id: UUID,
    current: CurrentUser = Depends(require_teacher_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    results = await repo.get_quiz_results(db, current.user_id, quiz_id)
    if results is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="quiz not found")
    return results
