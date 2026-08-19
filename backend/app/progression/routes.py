from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from ..common.deps import CurrentUser, get_current_user, get_db
from . import repository as repo

router = APIRouter(prefix="/me", tags=["profile"])


@router.get("/profile")
async def my_profile(
    current: CurrentUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """The authenticated user's progression: XP, streak, and recent matches."""
    profile = await repo.get_profile(db, current.user_id)
    if profile is None:
        raise HTTPException(status_code=404, detail="user not found")
    return profile