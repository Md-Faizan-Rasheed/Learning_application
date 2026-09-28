from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from ..common.deps import CurrentUser, get_current_user, get_db
from . import repository as repo
from .schemas import CampaignStageOut, ClaimResult

router = APIRouter(prefix="/campaign", tags=["campaign"])


def _derive_states(stages: list[dict]) -> list[dict]:
    """Stages are shown in order_no order. The first not-yet-completed stage
    is "current"; everything before it is "completed"; everything after it
    is "locked". Purely derived from completed_at — no extra column."""
    out = []
    unlocked = True
    for stage in stages:
        if stage["completed_at"] is not None:
            state = "completed"
        elif unlocked:
            state = "current"
            unlocked = False
        else:
            state = "locked"
        out.append({**stage, "state": state})
    return out


@router.get("/stages", response_model=list[CampaignStageOut])
async def list_stages(
    current: CurrentUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[CampaignStageOut]:
    """Every movement-stage, in order, with this player's own progress."""
    stages = await repo.get_stages_for_user(db, current.user_id)
    return [CampaignStageOut(**s) for s in _derive_states(stages)]


@router.post("/stage/{stage_id}/claim", response_model=ClaimResult)
async def claim_stage(
    stage_id: UUID,
    current: CurrentUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ClaimResult:
    """Claim a completed stage's XP reward. False (not an error) if the stage
    isn't complete yet or its reward was already claimed."""
    claimed = await repo.claim_stage_reward(
        db, user_id=current.user_id, stage_id=str(stage_id)
    )
    return ClaimResult(claimed=claimed)
