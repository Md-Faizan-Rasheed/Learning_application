from __future__ import annotations

import datetime as dt

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from . import rules


async def apply_match_result(
    db: AsyncSession, *, user_id: str, placement: int, correct_answers: int, today: dt.date
) -> dict:
    """Award XP and update the streak for one finished match. Returns a summary
    of what changed (for a post-match 'you earned…' screen)."""
    row = (
        await db.execute(
            text(
                "SELECT total_xp, streak_days, last_played_on "
                "FROM users WHERE id = :id"
            ),
            {"id": user_id},
        )
    ).mappings().first()
    if row is None:
        return {"xp_earned": 0, "total_xp": 0, "streak_days": 0, "streak_extended": False}

    xp_earned = rules.xp_for_match(placement=placement, correct_answers=correct_answers)
    new_streak, counted_today = rules.next_streak(
        last_played_on=row["last_played_on"],
        today=today,
        current_streak=row["streak_days"] or 0,
    )
    new_total = (row["total_xp"] or 0) + xp_earned

    await db.execute(
        text(
            """
            UPDATE users
            SET total_xp = :xp,
                streak_days = :streak,
                last_played_on = :today
            WHERE id = :id
            """
        ),
        {"xp": new_total, "streak": new_streak, "today": today, "id": user_id},
    )

    return {
        "xp_earned": xp_earned,
        "total_xp": new_total,
        "streak_days": new_streak,
        "streak_extended": counted_today,
    }


async def get_profile(db: AsyncSession, user_id: str) -> dict | None:
    user = (
        await db.execute(
            text(
                "SELECT id, display_name, total_xp, streak_days, streak_freezes, "
                "last_played_on FROM users WHERE id = :id"
            ),
            {"id": user_id},
        )
    ).mappings().first()
    if user is None:
        return None

    history = (
        await db.execute(
            text(
                """
                SELECT m.id AS match_id, m.difficulty::text AS difficulty,
                       mp.placement, mp.final_score, m.ended_at
                FROM match_players mp
                JOIN matches m ON m.id = mp.match_id
                WHERE mp.user_id = :id AND mp.is_bot = FALSE
                ORDER BY m.created_at DESC
                LIMIT 10
                """
            ),
            {"id": user_id},
        )
    ).mappings().all()

    return {
        "user_id": str(user["id"]),
        "display_name": user["display_name"],
        "total_xp": user["total_xp"],
        "streak_days": user["streak_days"],
        "streak_freezes": user["streak_freezes"],
        "last_played_on": user["last_played_on"].isoformat() if user["last_played_on"] else None,
        "recent_matches": [
            {
                "match_id": str(h["match_id"]),
                "difficulty": h["difficulty"],
                "placement": h["placement"],
                "final_score": h["final_score"],
            }
            for h in history
        ],
    }