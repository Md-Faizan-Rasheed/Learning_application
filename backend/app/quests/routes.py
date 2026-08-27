from __future__ import annotations

import datetime as dt

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from ..common.deps import CurrentUser, get_current_user, get_db
from . import repository as repo

router = APIRouter(prefix="/me", tags=["quests"])


@router.get("/quests")
async def my_quests(
    current: CurrentUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Today's daily quests for the authenticated user, with progress."""
    quests = await repo.get_todays_quests(db, current.user_id, dt.date.today())
    return {"date": dt.date.today().isoformat(), "quests": quests}
