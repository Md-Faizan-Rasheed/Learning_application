from __future__ import annotations

import datetime as dt

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

    # The actual words found this session (word_search only) — lets the
    # server track *which* words a user has ever found, not just how many,
    # so a "found every word in a category" achievement is possible. Capped
    # generously; a real puzzle never has more than ~10 words anyway.
    words: list[str] = Field(default_factory=list, max_length=50)

    # Set only when this session was the Word Search Daily Challenge (the
    # client-computed calendar date the shared puzzle was seeded from) —
    # records/updates that day's leaderboard entry. Omitted for regular
    # free-play word search.
    challenge_date: dt.date | None = None
