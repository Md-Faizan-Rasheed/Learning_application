from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, status

from ..common.deps import CurrentUser, get_current_user_optional
from .schemas import TapThroughEventIn

router = APIRouter(prefix="/telemetry", tags=["telemetry"])
logger = logging.getLogger("telemetry.tap_through")


@router.post("/tap-through", status_code=status.HTTP_204_NO_CONTENT)
async def log_tap_through(
    event: TapThroughEventIn,
    current: CurrentUser | None = Depends(get_current_user_optional),
) -> None:
    """Records one card tap from the Home screen's Today's Journey / Quick
    Play scrollers — the usage data needed before deciding whether/how to
    unify them into one navigation surface. Log-only, no table: cheap to
    ship, and log aggregation is enough to compute tap-through counts per
    section/card. Auth is optional and never enforced — a dropped or
    unauthenticated event is fine, this must never be able to block or
    error out a tap.
    """
    logger.info(
        "tap_through section=%s card_id=%s user_id=%s client_ts=%s",
        event.section,
        event.card_id,
        current.user_id if current else None,
        event.client_timestamp.isoformat(),
    )
