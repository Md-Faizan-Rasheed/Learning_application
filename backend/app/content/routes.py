from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..common.deps import CurrentUser, get_current_user, get_db, require_admin_user
from ..contributions.repository import award_approval_xp
from . import bulk_import, repository as repo
from .schemas import (
    BulkImportRequest,
    BulkImportResult,
    CategoryCreate,
    CategoryOut,
    CategoryUpdate,
    QuestionCreate,
    QuestionListItem,
    QuestionOut,
    QuestionUpdate,
)

# Admin-only: real admin/developer JWT, or legacy X-Admin-Key during migration.
router = APIRouter(prefix="/admin", tags=["content-admin"], dependencies=[Depends(require_admin_user)])

# Public (any authenticated user): active categories, for any player-facing
# feature that needs real category ids rather than the client's hardcoded
# practice-category slugs — currently just the contribution form.
public_router = APIRouter(tags=["content-public"])


@public_router.get("/categories", response_model=list[CategoryOut])
async def list_public_categories(
    current: CurrentUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[dict]:
    return await repo.list_categories(db, active_only=True)


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


@router.patch("/categories/{category_id}", response_model=CategoryOut)
async def update_category(
    category_id: UUID, data: CategoryUpdate, db: AsyncSession = Depends(get_db)
) -> dict:
    result = await repo.update_category(db, category_id, data)
    if result is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="category not found")
    return result


@router.get("/questions", response_model=list[QuestionListItem])
async def list_questions(
    category_id: UUID | None = None,
    review_state: str | None = None,
    search: str | None = None,
    limit: int = 50,
    offset: int = 0,
    db: AsyncSession = Depends(get_db),
) -> list[dict]:
    if review_state is not None and review_state not in ("draft", "reviewed", "live"):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="review_state must be draft, reviewed, or live",
        )
    return await repo.list_questions(
        db, category_id=category_id, review_state=review_state, search=search, limit=limit, offset=offset
    )


@router.get("/questions/{question_id}", response_model=QuestionOut)
async def get_question(question_id: UUID, db: AsyncSession = Depends(get_db)) -> dict:
    result = await repo.get_question(db, question_id)
    if result is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="question not found")
    return result


@router.patch("/questions/{question_id}", response_model=QuestionOut)
async def update_question(
    question_id: UUID, data: QuestionUpdate, db: AsyncSession = Depends(get_db)
) -> dict:
    if data.category_id is not None and not await repo.category_exists(db, data.category_id):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="category_id does not exist",
        )
    result = await repo.update_question(db, question_id, data)
    if result is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="question not found")
    return result


@router.delete("/questions/{question_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_question(question_id: UUID, db: AsyncSession = Depends(get_db)) -> None:
    try:
        deleted = await repo.delete_question(db, question_id)
    except IntegrityError:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="question has attempt/quiz history and cannot be deleted; "
            "set its review state back to 'draft' to hide it instead",
        )
    if not deleted:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="question not found")


@router.post("/questions", response_model=QuestionOut, status_code=status.HTTP_201_CREATED)
async def create_question(data: QuestionCreate, db: AsyncSession = Depends(get_db)) -> dict:
    if not await repo.category_exists(db, data.category_id):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="category_id does not exist",
        )
    return await repo.create_question(db, data)


@router.post("/questions/bulk-import", response_model=BulkImportResult)
async def bulk_import_questions(data: BulkImportRequest, db: AsyncSession = Depends(get_db)) -> BulkImportResult:
    try:
        raw_rows = (
            bulk_import.parse_json_rows(data.content)
            if data.format == "json"
            else bulk_import.parse_csv_rows(data.content)
        )
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(e))
    return await bulk_import.import_rows(db, raw_rows)


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
    before = await repo.get_review_state_and_owner(db, question_id)
    result = await repo.set_review_state(db, question_id, state)
    if result is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="question not found")
    if (
        state == "live"
        and before is not None
        and before["review_state"] != "live"
        and before["created_by"] is not None
    ):
        await award_approval_xp(db, str(before["created_by"]))
    return result