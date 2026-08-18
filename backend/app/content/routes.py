from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..common.deps import get_db, require_admin
from . import repository as repo
from .schemas import (
    CategoryCreate,
    CategoryOut,
    QuestionCreate,
    QuestionOut,
)

# All routes here are admin-only (temporary key gate — see require_admin).
router = APIRouter(prefix="/admin", tags=["content-admin"], dependencies=[Depends(require_admin)])


@router.post("/categories", response_model=CategoryOut, status_code=status.HTTP_201_CREATED)
async def create_category(data: CategoryCreate, db: AsyncSession = Depends(get_db)) -> dict:
    try:
        return await repo.create_category(db, data)
    except IntegrityError:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"category slug '{data.slug}' already exists",
        )


@router.get("/categories", response_model=list[CategoryOut])
async def list_categories(db: AsyncSession = Depends(get_db)) -> list[dict]:
    return await repo.list_categories(db, active_only=False)


@router.post("/questions", response_model=QuestionOut, status_code=status.HTTP_201_CREATED)
async def create_question(data: QuestionCreate, db: AsyncSession = Depends(get_db)) -> dict:
    if not await repo.category_exists(db, data.category_id):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="category_id does not exist",
        )
    return await repo.create_question(db, data)


@router.post("/questions/{question_id}/review", response_model=QuestionOut)
async def review_question(
    question_id: UUID,
    state: str,
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Promote a question through the scholar-review workflow.
    state must be one of: draft, reviewed, live. Only 'live' questions are served."""
    if state not in ("draft", "reviewed", "live"):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="state must be draft, reviewed, or live",
        )
    result = await repo.set_review_state(db, question_id, state)
    if result is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="question not found")
    return result


