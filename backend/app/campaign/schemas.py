from __future__ import annotations

from uuid import UUID

from pydantic import BaseModel


class CampaignStageOut(BaseModel):
    id: UUID
    slug: str
    name: dict          # {en, ur, ar}
    description: dict | None
    order_no: int
    state: str           # "locked" | "current" | "completed"
    progress: int
    target: int
    # Live count of 'live' questions tagged to this stage's event(s) —
    # always computed fresh (see repository.get_stages_for_user), never
    # cached, so it reflects admin tagging changes immediately.
    question_count: int


class ClaimResult(BaseModel):
    claimed: bool
