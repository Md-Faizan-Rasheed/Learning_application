from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from ..common.deps import CurrentUser, get_current_user, get_db
from ..content.repository import category_exists
from . import repository as repo
from .schemas import ContributionCreate, ContributionOut

router = APIRouter(prefix="/contributions", tags=["contributions"])


@router.post("", response_model=ContributionOut, status_code=status.HTTP_201_CREATED)
async def submit_contribution(
    data: ContributionCreate,
    current: CurrentUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Any authenticated user may submit a question — it starts as a public
    draft and needs an admin to promote it to 'live' before it's served to
    players or the contributor is rewarded."""
    if not await category_exists(db, data.category_id):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="category_id does not exist")
    return await repo.create_contribution(db, current.user_id, data)


@router.get("/mine", response_model=list[ContributionOut])
async def list_my_contributions(
    current: CurrentUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[dict]:
    return await repo.list_my_contributions(db, current.user_id)
