from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from ..common.deps import CurrentUser, get_current_user, get_db, require_admin_user
from . import repository as repo
from .schemas import (
    AdminReportOut,
    BlockCreate,
    BlockedUserOut,
    ReportCreate,
    ReportOut,
    ReportStatusUpdate,
)

router = APIRouter(prefix="/moderation", tags=["moderation"])

# Admin-only: reviewing the report queue. Separate router (same pattern as
# content/routes.py's admin router) so it can carry its own dependency gate.
admin_router = APIRouter(prefix="/admin", tags=["moderation-admin"], dependencies=[Depends(require_admin_user)])


@router.post("/report", response_model=ReportOut, status_code=status.HTTP_201_CREATED)
async def report_user(
    data: ReportCreate,
    current: CurrentUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    reported_id = str(data.reported_user_id)
    if reported_id == current.user_id:
        raise HTTPException(status_code=400, detail="you can't report yourself")
    if not await repo.user_exists(db, reported_id):
        raise HTTPException(status_code=404, detail="user not found")
    return await repo.create_report(
        db,
        reporter_id=current.user_id,
        reported_user_id=reported_id,
        reason=data.reason,
        details=data.details,
        match_id=str(data.match_id) if data.match_id else None,
    )


@router.post("/block", status_code=status.HTTP_201_CREATED)
async def block_user(
    data: BlockCreate,
    current: CurrentUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    blocked_id = str(data.user_id)
    if blocked_id == current.user_id:
        raise HTTPException(status_code=400, detail="you can't block yourself")
    if not await repo.user_exists(db, blocked_id):
        raise HTTPException(status_code=404, detail="user not found")
    await repo.block_user(db, current.user_id, blocked_id)
    return {"ok": True}


@router.delete("/block/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def unblock_user(
    user_id: str,
    current: CurrentUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    await repo.unblock_user(db, current.user_id, user_id)


@router.get("/blocked", response_model=list[BlockedUserOut])
async def list_blocked(
    current: CurrentUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[dict]:
    return await repo.list_blocked(db, current.user_id)


@admin_router.get("/reports", response_model=list[AdminReportOut])
async def list_reports(
    report_status: str = "open",
    db: AsyncSession = Depends(get_db),
) -> list[dict]:
    return await repo.list_reports(db, report_status)


@admin_router.patch("/reports/{report_id}", response_model=ReportOut)
async def update_report_status(
    report_id: str,
    data: ReportStatusUpdate,
    db: AsyncSession = Depends(get_db),
) -> dict:
    result = await repo.set_report_status(db, report_id, data.status)
    if result is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="report not found")
    return result
