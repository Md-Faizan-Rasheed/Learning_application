"""Scoring rules. Pure functions, no I/O — the single source of truth for
how points are awarded. Lives on the server only; the client never computes
score (locked decision 14.4: correct = base x speed, wrong/timeout = 0)."""

from __future__ import annotations

# Base points per difficulty (locked decision 14.2 / difficulty table).
BASE_POINTS = {"easy": 20, "medium": 35, "hard": 50}

# How long a question is "live" for full-speed credit, in milliseconds.
QUESTION_TIME_MS = 20_000


def score_answer(
    *,
    difficulty: str,
    is_correct: bool,
    response_ms: int | None,
) -> int:
    """Points for a single answer.

    - Wrong answer or timeout (no/late response): 0.
    - Correct answer: base(difficulty) scaled by speed. Answering instantly
      earns full base; answering right at the buzzer earns a floor fraction.
    """
    if not is_correct:
        return 0
    if response_ms is None or response_ms < 0:
        return 0
    if response_ms >= QUESTION_TIME_MS:
        # Correct but out of time -> no speed bonus, minimal credit.
        return 0

    base = BASE_POINTS.get(difficulty, 0)
    # Linear speed factor from 1.0 (instant) down to 0.5 (last moment).
    speed_factor = 1.0 - 0.5 * (response_ms / QUESTION_TIME_MS)
    return round(base * speed_factor)