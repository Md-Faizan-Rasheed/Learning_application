"""Progression rules — pure functions, no I/O. The single source of truth for
how XP is earned and how the daily streak advances."""

from __future__ import annotations

import datetime as dt

# XP awards. Tunable in one place.
XP_PER_MATCH = 10          # just for finishing
XP_PER_CORRECT = 5         # per correct answer in the match
XP_PLACEMENT = {1: 30, 2: 15, 3: 5, 4: 0}  # bonus by finishing position

# Solo activities (e.g. Word Search) have no placement, so they're scored
# on their own scale rather than reusing the match constants above — kept
# roughly comparable in size (a full hard puzzle ~= a mid-placement match).
XP_PER_ACTIVITY = 5             # flat credit for finishing any solo activity
XP_PER_WORD_FOUND = 2
WORD_SEARCH_DIFFICULTY_BONUS = {"easy": 0, "medium": 5, "hard": 10}


def xp_for_match(*, placement: int, correct_answers: int) -> int:
    """Total XP earned from one finished match."""
    return (
        XP_PER_MATCH
        + XP_PER_CORRECT * max(0, correct_answers)
        + XP_PLACEMENT.get(placement, 0)
    )


def xp_for_word_search(*, difficulty: str, words_found: int, hints_used: int) -> int:
    """Total XP earned from one completed Word Search puzzle: a flat
    completion credit, plus per word found, plus a difficulty bonus, minus a
    small penalty per hint used — floored at 0 so a hint-heavy completion
    can never be worth negative XP."""
    base = (
        XP_PER_ACTIVITY
        + XP_PER_WORD_FOUND * max(0, words_found)
        + WORD_SEARCH_DIFFICULTY_BONUS.get(difficulty, 0)
    )
    return max(0, base - max(0, hints_used))


def next_streak(
    *, last_played_on: dt.date | None, today: dt.date, current_streak: int
) -> tuple[int, bool]:
    """Compute the new streak given when the user last played.

    Returns (new_streak_days, counted_today).
    - First play ever, or after a gap of >1 day: streak resets to 1.
    - Consecutive day (yesterday): streak increments.
    - Same day: unchanged (already counted today).
    """
    if last_played_on is None:
        return 1, True
    if last_played_on == today:
        return current_streak, False  # already counted today
    if last_played_on == today - dt.timedelta(days=1):
        return current_streak + 1, True  # consecutive day
    return 1, True  # gap -> reset to a fresh 1-day streak