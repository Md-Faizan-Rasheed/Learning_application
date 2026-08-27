from __future__ import annotations

import datetime as dt

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from . import catalog


async def ensure_todays_quests(db: AsyncSession, user_id: str, today: dt.date) -> None:
    """Create this user's quest rows for `today` if they don't exist yet.
    Idempotent via the UNIQUE(user_id, quest_date, quest_key) constraint."""
    for q in catalog.DAILY_QUESTS:
        await db.execute(
            text(
                """
                INSERT INTO daily_quests
                    (user_id, quest_date, quest_key, description, target, reward_xp)
                VALUES (:u, :d, :k, :desc, :t, :xp)
                ON CONFLICT (user_id, quest_date, quest_key) DO NOTHING
                """
            ),
            {
                "u": user_id,
                "d": today,
                "k": q.key,
                "desc": q.description,
                "t": q.target,
                "xp": q.reward_xp,
            },
        )


async def get_todays_quests(db: AsyncSession, user_id: str, today: dt.date) -> list[dict]:
    await ensure_todays_quests(db, user_id, today)
    rows = (
        await db.execute(
            text(
                """
                SELECT quest_key, description, target, progress, completed, reward_xp
                FROM daily_quests
                WHERE user_id = :u AND quest_date = :d
                ORDER BY quest_key
                """
            ),
            {"u": user_id, "d": today},
        )
    ).mappings().all()
    return [dict(r) for r in rows]


async def advance_quests(
    db: AsyncSession, user_id: str, today: dt.date, *, event: str, amount: int
) -> list[dict]:
    """Advance every quest tied to `event` by `amount`. Returns any quests that
    were newly completed by this call (for the client to celebrate), and awards
    their reward XP exactly once."""
    if amount <= 0:
        return []
    await ensure_todays_quests(db, user_id, today)

    newly_completed: list[dict] = []
    for q in catalog.quests_for_event(event):
        # Advance progress, clamped at target; mark completed when reached.
        row = (
            await db.execute(
                text(
                    """
                    UPDATE daily_quests
                    SET progress = LEAST(progress + :amt, target),
                        completed = (LEAST(progress + :amt, target) >= target)
                    WHERE user_id = :u AND quest_date = :d AND quest_key = :k
                      AND completed = FALSE
                    RETURNING quest_key, description, target, progress, completed, reward_xp
                    """
                ),
                {"amt": amount, "u": user_id, "d": today, "k": q.key},
            )
        ).mappings().first()
        if row and row["completed"] and not await _reward_claimed(db, user_id, today, q.key):
            # award reward XP once, mark claimed
            await db.execute(
                text("UPDATE users SET total_xp = total_xp + :xp WHERE id = :u"),
                {"xp": q.reward_xp, "u": user_id},
            )
            await db.execute(
                text(
                    "UPDATE daily_quests SET reward_claimed = TRUE "
                    "WHERE user_id = :u AND quest_date = :d AND quest_key = :k"
                ),
                {"u": user_id, "d": today, "k": q.key},
            )
            newly_completed.append(dict(row))
    return newly_completed


async def _reward_claimed(db: AsyncSession, user_id: str, today: dt.date, key: str) -> bool:
    row = (
        await db.execute(
            text(
                "SELECT reward_claimed FROM daily_quests "
                "WHERE user_id = :u AND quest_date = :d AND quest_key = :k"
            ),
            {"u": user_id, "d": today, "k": key},
        )
    ).first()
    return bool(row[0]) if row else False