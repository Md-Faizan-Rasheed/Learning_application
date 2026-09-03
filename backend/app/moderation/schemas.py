from __future__ import annotations

from uuid import UUID

from pydantic import BaseModel, Field, field_validator

REPORT_REASONS = ("inappropriate_name", "cheating", "harassment", "spam", "other")
REPORT_STATUSES = ("open", "reviewed", "dismissed")


class ReportCreate(BaseModel):
    reported_user_id: UUID
    reason: str
    details: str | None = Field(default=None, max_length=1000)
    match_id: UUID | None = None

    @field_validator("reason")
    @classmethod
    def valid_reason(cls, v: str) -> str:
        if v not in REPORT_REASONS:
            raise ValueError(f"reason must be one of {REPORT_REASONS}")
        return v


class ReportOut(BaseModel):
    id: UUID
    reported_user_id: UUID
    reason: str
    status: str


class AdminReportOut(BaseModel):
    id: UUID
    reporter_id: UUID
    reporter_name: str
    reported_user_id: UUID
    reported_name: str
    reason: str
    details: str | None
    match_id: UUID | None
    status: str
    created_at: str


class ReportStatusUpdate(BaseModel):
    status: str

    @field_validator("status")
    @classmethod
    def valid_status(cls, v: str) -> str:
        if v not in ("reviewed", "dismissed"):
            raise ValueError("status must be reviewed or dismissed")
        return v


class BlockCreate(BaseModel):
    user_id: UUID


class BlockedUserOut(BaseModel):
    user_id: UUID
    display_name: str
