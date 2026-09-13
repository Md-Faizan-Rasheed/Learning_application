from __future__ import annotations

import datetime as dt

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from ..common.deps import CurrentUser, get_current_user, get_db
from ..social import repository as social_repo
from . import repository as repo
from . import rules
from .schemas import ActivityCompleteIn

router = APIRouter(prefix="/me", tags=["profile"])

# Activities this endpoint knows how to score. Adding a new solo activity
# means adding its xp_for_* rule and a branch here — same shape as
# game/scoring.py's per-difficulty table.
_ACTIVITY_SCORERS = {
    "word_search": lambda data: rules.xp_for_word_search(
        difficulty=data.difficulty,
        words_found=min(data.words_found, data.total_words),
        hints_used=data.hints_used,
    ),
}


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


@router.post("/activity/complete")
async def complete_activity(
    data: ActivityCompleteIn,
    current: CurrentUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Award XP + streak credit for a finished solo learning activity (e.g.
    Word Search) — the non-match equivalent of a multiplayer match ending.
    XP is always computed here from the reported fields, never accepted
    from the client directly."""
    scorer = _ACTIVITY_SCORERS.get(data.activity)
    if scorer is None:
        raise HTTPException(status_code=422, detail=f"unknown activity: {data.activity}")

    xp_earned = scorer(data)

    if data.activity == "word_search" and data.words:
        if not data.category:
            raise HTTPException(status_code=422, detail="category is required with words")
        await repo.record_word_search_finds(
            db, user_id=current.user_id, category=data.category, words=data.words
        )

    return await repo.apply_activity_result(
        db, user_id=current.user_id, xp_earned=xp_earned, today=dt.date.today()
    )


@router.get("/leaderboard")
async def leaderboard(
    current: CurrentUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Top players ranked by total XP."""
    return {"players": await repo.get_leaderboard(db, current.user_id)}


@router.get("/leaderboard/nearby")
async def leaderboard_nearby(
    current: CurrentUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """The caller's own rank plus a small window of players around them —
    works even when the caller isn't in the top-N global list."""
    return {"players": await repo.get_my_rank_and_nearby(db, current.user_id)}


@router.get("/leaderboard/friends")
async def leaderboard_friends(
    current: CurrentUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Same shape as the global leaderboard, scoped to the caller plus their
    accepted friends."""
    friend_ids = await social_repo.get_friend_ids(db, current.user_id)
    return {"players": await repo.get_friends_leaderboard(db, current.user_id, friend_ids)}