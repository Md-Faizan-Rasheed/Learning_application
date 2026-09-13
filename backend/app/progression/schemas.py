from __future__ import annotations

from pydantic import BaseModel, Field


class ActivityCompleteIn(BaseModel):
    """Report of a finished solo learning activity. Only fields that feed
    the server-side XP formula are trusted — the client never gets to hand
    over an XP amount directly (same rule game/scoring.py already follows
    for match answers)."""

    activity: str = Field(..., description="e.g. 'word_search'")
    category: str | None = None
    difficulty: str
    words_found: int = Field(ge=0)
    total_words: int = Field(ge=0)
    seconds: int = Field(ge=0)
    hints_used: int = Field(ge=0)
