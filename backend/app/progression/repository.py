from __future__ import annotations

import datetime as dt

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from . import rules


async def _apply_xp_and_streak(
    db: AsyncSession, *, user_id: str, xp_earned: int, today: dt.date
) -> dict:
    """Shared by apply_match_result and apply_activity_result: award
    already-computed XP and advance the daily streak. Returns a summary of
    what changed (for a post-session 'you earned…' screen)."""
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


async def apply_match_result(
    db: AsyncSession, *, user_id: str, placement: int, correct_answers: int, today: dt.date
) -> dict:
    """Award XP and update the streak for one finished match."""
    xp_earned = rules.xp_for_match(placement=placement, correct_answers=correct_answers)
    return await _apply_xp_and_streak(db, user_id=user_id, xp_earned=xp_earned, today=today)


async def apply_activity_result(
    db: AsyncSession, *, user_id: str, xp_earned: int, today: dt.date
) -> dict:
    """Award XP and update the streak for a completed solo activity (e.g. a
    Word Search puzzle) — the non-match equivalent of apply_match_result.
    Takes the already-computed xp_earned directly since solo activities have
    no placement to score from."""
    return await _apply_xp_and_streak(db, user_id=user_id, xp_earned=xp_earned, today=today)


async def get_leaderboard(db: AsyncSession, current_user_id: str, limit: int = 30) -> list[dict]:
    """Top players by total XP, for the global leaderboard screen. Includes
    is_me so the client can highlight the caller's own row without having to
    match on display_name (which isn't even unique)."""
    rows = (
        await db.execute(
            text(
                """
                SELECT id, display_name, total_xp, streak_days, (id = :uid) AS is_me
                FROM users
                ORDER BY total_xp DESC, streak_days DESC, id
                LIMIT :limit
                """
            ),
            {"limit": limit, "uid": current_user_id},
        )
    ).mappings().all()

    return [
        {
            "id": str(r["id"]),
            "placement": i + 1,
            "display_name": r["display_name"],
            "total_xp": r["total_xp"] or 0,
            "streak_days": r["streak_days"] or 0,
            "is_me": r["is_me"],
        }
        for i, r in enumerate(rows)
    ]


async def get_my_rank_and_nearby(db: AsyncSession, current_user_id: str, window: int = 2) -> list[dict]:
    """The caller's real rank plus a small window of players immediately
    above/below them, regardless of whether they're in the top N — the
    top-N query above can't answer "where am I" if the caller isn't in it.

    Uses ROW_NUMBER (not RANK) with `id` as a final tiebreaker: with RANK,
    a big pile of tied users (e.g. many fresh accounts at 0 XP) all share one
    placement, so a naive "placement BETWEEN my_rank-2 AND my_rank+2" filter
    can pull in dozens of rows instead of ~5. ROW_NUMBER guarantees a unique,
    bounded window, and the same tiebreak is used in get_leaderboard above so
    a user's placement matches between the two endpoints."""
    rows = (
        await db.execute(
            text(
                """
                WITH ranked AS (
                    SELECT id, display_name, total_xp, streak_days,
                           ROW_NUMBER() OVER (ORDER BY total_xp DESC, streak_days DESC, id) AS placement
                    FROM users
                ),
                me AS (SELECT placement FROM ranked WHERE id = :uid)
                SELECT ranked.id, ranked.display_name, ranked.total_xp, ranked.streak_days,
                       ranked.placement, (ranked.id = :uid) AS is_me
                FROM ranked, me
                WHERE ranked.placement BETWEEN me.placement - :window AND me.placement + :window
                ORDER BY ranked.placement
                """
            ),
            {"uid": current_user_id, "window": window},
        )
    ).mappings().all()

    return [
        {
            "id": str(r["id"]),
            "placement": r["placement"],
            "display_name": r["display_name"],
            "total_xp": r["total_xp"] or 0,
            "streak_days": r["streak_days"] or 0,
            "is_me": r["is_me"],
        }
        for r in rows
    ]


async def get_friends_leaderboard(db: AsyncSession, current_user_id: str, friend_ids: list[str]) -> list[dict]:
    """Same shape as get_leaderboard, scoped to the caller plus their
    accepted friends (friend_ids resolved by the caller from
    social/repository.py's get_friend_ids)."""
    ids = [*friend_ids, current_user_id]
    rows = (
        await db.execute(
            text(
                """
                SELECT id, display_name, total_xp, streak_days, (id = :uid) AS is_me
                FROM users
                WHERE id = ANY(CAST(:ids AS uuid[]))
                ORDER BY total_xp DESC, streak_days DESC, id
                """
            ),
            {"ids": ids, "uid": current_user_id},
        )
    ).mappings().all()

    return [
        {
            "id": str(r["id"]),
            "placement": i + 1,
            "display_name": r["display_name"],
            "total_xp": r["total_xp"] or 0,
            "streak_days": r["streak_days"] or 0,
            "is_me": r["is_me"],
        }
        for i, r in enumerate(rows)
    ]


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

    approved_questions = (
        await db.execute(
            text("SELECT count(*) FROM questions WHERE created_by = :id AND review_state = 'live'"),
            {"id": user_id},
        )
    ).scalar()

    return {
        "user_id": str(user["id"]),
        "display_name": user["display_name"],
        "total_xp": user["total_xp"],
        "streak_days": user["streak_days"],
        "streak_freezes": user["streak_freezes"],
        "last_played_on": user["last_played_on"].isoformat() if user["last_played_on"] else None,
        "approved_question_count": approved_questions or 0,
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