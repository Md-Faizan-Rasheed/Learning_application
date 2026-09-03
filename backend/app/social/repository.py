from __future__ import annotations

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

# Flat XP bonus for winning an async friend challenge. A tie awards nothing.
CHALLENGE_WIN_XP = 20

_CHALLENGE_DETAIL_SELECT = """
    SELECT c.id, c.challenger_id, cu.display_name AS challenger_name,
           c.opponent_id, ou.display_name AS opponent_name,
           c.category, c.question_count, c.challenger_score, c.opponent_score,
           c.status, c.winner_id, c.created_at, c.completed_at
    FROM challenges c
    JOIN users cu ON cu.id = c.challenger_id
    JOIN users ou ON ou.id = c.opponent_id
"""


async def get_friend_code(db: AsyncSession, user_id: str) -> str | None:
    row = (await db.execute(text("SELECT friend_code FROM users WHERE id = :u"), {"u": user_id})).first()
    return row[0] if row else None


async def find_user_by_code(db: AsyncSession, code: str) -> dict | None:
    row = (
        await db.execute(
            text("SELECT id, display_name FROM users WHERE friend_code = :c"),
            {"c": code.strip().upper()},
        )
    ).mappings().first()
    return dict(row) if row else None


async def get_user_basic(db: AsyncSession, user_id: str) -> dict | None:
    """Like find_user_by_code but by primary key — used for the direct
    add-friend flow (e.g. "add the opponent I just played with")."""
    row = (
        await db.execute(
            text("SELECT id, display_name FROM users WHERE id = :u"),
            {"u": user_id},
        )
    ).mappings().first()
    return dict(row) if row else None


async def existing_relationship(db: AsyncSession, a: str, b: str) -> str | None:
    """Status of any existing pending/accepted request between the two users
    in either direction, or None if there isn't one. Declined requests don't
    block a fresh request, so they're excluded here."""
    row = (
        await db.execute(
            text(
                """
                SELECT status FROM friend_requests
                WHERE ((from_user_id = :a AND to_user_id = :b) OR (from_user_id = :b AND to_user_id = :a))
                  AND status IN ('pending', 'accepted')
                LIMIT 1
                """
            ),
            {"a": a, "b": b},
        )
    ).first()
    return row[0] if row else None


async def create_friend_request(db: AsyncSession, from_user_id: str, to_user_id: str) -> dict:
    row = (
        await db.execute(
            text(
                """
                INSERT INTO friend_requests (from_user_id, to_user_id)
                VALUES (:f, :t)
                RETURNING id, from_user_id, to_user_id, status
                """
            ),
            {"f": from_user_id, "t": to_user_id},
        )
    ).mappings().one()
    return dict(row)


async def list_incoming_requests(db: AsyncSession, user_id: str) -> list[dict]:
    rows = (
        await db.execute(
            text(
                """
                SELECT fr.id, fr.from_user_id, u.display_name, u.total_xp
                FROM friend_requests fr
                JOIN users u ON u.id = fr.from_user_id
                WHERE fr.to_user_id = :u AND fr.status = 'pending'
                ORDER BY fr.created_at DESC
                """
            ),
            {"u": user_id},
        )
    ).mappings().all()
    return [dict(r) for r in rows]


async def respond_to_request(db: AsyncSession, user_id: str, request_id: str, accept: bool) -> dict | None:
    new_status = "accepted" if accept else "declined"
    row = (
        await db.execute(
            text(
                """
                UPDATE friend_requests
                SET status = :s, responded_at = now()
                WHERE id = :id AND to_user_id = :u AND status = 'pending'
                RETURNING id, from_user_id, to_user_id, status
                """
            ),
            {"s": new_status, "id": request_id, "u": user_id},
        )
    ).mappings().first()
    return dict(row) if row else None


async def list_friends(db: AsyncSession, user_id: str) -> list[dict]:
    rows = (
        await db.execute(
            text(
                """
                SELECT u.id, u.display_name, u.total_xp, u.streak_days
                FROM friend_requests fr
                JOIN users u ON u.id = CASE WHEN fr.from_user_id = :u THEN fr.to_user_id ELSE fr.from_user_id END
                WHERE fr.status = 'accepted' AND (fr.from_user_id = :u OR fr.to_user_id = :u)
                ORDER BY u.total_xp DESC
                """
            ),
            {"u": user_id},
        )
    ).mappings().all()
    return [dict(r) for r in rows]


async def get_friend_ids(db: AsyncSession, user_id: str) -> list[str]:
    """Just the ids, for the friends-leaderboard query in progression/repository.py."""
    rows = (
        await db.execute(
            text(
                """
                SELECT CASE WHEN from_user_id = :u THEN to_user_id ELSE from_user_id END AS friend_id
                FROM friend_requests
                WHERE status = 'accepted' AND (from_user_id = :u OR to_user_id = :u)
                """
            ),
            {"u": user_id},
        )
    ).all()
    return [str(r[0]) for r in rows]


async def are_friends(db: AsyncSession, a: str, b: str) -> bool:
    row = (
        await db.execute(
            text(
                """
                SELECT 1 FROM friend_requests
                WHERE status = 'accepted'
                  AND ((from_user_id = :a AND to_user_id = :b) OR (from_user_id = :b AND to_user_id = :a))
                LIMIT 1
                """
            ),
            {"a": a, "b": b},
        )
    ).first()
    return row is not None


async def unfriend(db: AsyncSession, user_id: str, friend_user_id: str) -> None:
    await db.execute(
        text(
            """
            DELETE FROM friend_requests
            WHERE status = 'accepted'
              AND ((from_user_id = :u AND to_user_id = :f) OR (from_user_id = :f AND to_user_id = :u))
            """
        ),
        {"u": user_id, "f": friend_user_id},
    )


# ---------- challenges ----------


async def create_challenge(
    db: AsyncSession, challenger_id: str, opponent_id: str, category: str, question_count: int
) -> dict:
    row = (
        await db.execute(
            text(
                """
                INSERT INTO challenges (challenger_id, opponent_id, category, question_count)
                VALUES (:c, :o, :cat, :qc)
                RETURNING id
                """
            ),
            {"c": challenger_id, "o": opponent_id, "cat": category, "qc": question_count},
        )
    ).mappings().one()
    return dict(row)


async def get_challenge(db: AsyncSession, challenge_id: str) -> dict | None:
    row = (
        await db.execute(
            text(
                """
                SELECT id, challenger_id, opponent_id, category, question_count,
                       challenger_score, opponent_score, status, winner_id
                FROM challenges WHERE id = :id
                """
            ),
            {"id": challenge_id},
        )
    ).mappings().first()
    return dict(row) if row else None


async def get_challenge_detail(db: AsyncSession, challenge_id: str) -> dict | None:
    row = (
        await db.execute(text(_CHALLENGE_DETAIL_SELECT + " WHERE c.id = :id"), {"id": challenge_id})
    ).mappings().first()
    return dict(row) if row else None


async def list_my_challenges(db: AsyncSession, user_id: str) -> list[dict]:
    rows = (
        await db.execute(
            text(_CHALLENGE_DETAIL_SELECT + " WHERE c.challenger_id = :u OR c.opponent_id = :u ORDER BY c.created_at DESC"),
            {"u": user_id},
        )
    ).mappings().all()
    return [dict(r) for r in rows]


async def submit_challenge_score(db: AsyncSession, challenge_id: str, user_id: str, correct_count: int) -> None:
    """Records the caller's tally for this challenge. If both sides have now
    submitted, finalizes status/winner and awards a one-time XP bonus to the
    winner (a tie awards no bonus)."""
    challenge = await get_challenge(db, challenge_id)
    if challenge is None:
        return

    is_challenger = user_id == str(challenge["challenger_id"])
    score_col = "challenger_score" if is_challenger else "opponent_score"
    await db.execute(
        text(f"UPDATE challenges SET {score_col} = :s WHERE id = :id"),
        {"s": correct_count, "id": challenge_id},
    )

    challenge = await get_challenge(db, challenge_id)
    challenger_score = challenge["challenger_score"]
    opponent_score = challenge["opponent_score"]
    if challenger_score is None or opponent_score is None:
        return  # still waiting on the other player

    winner_id = None
    if challenger_score != opponent_score:
        winner_id = challenge["challenger_id"] if challenger_score > opponent_score else challenge["opponent_id"]

    await db.execute(
        text(
            """
            UPDATE challenges
            SET status = 'completed', winner_id = :w, completed_at = now()
            WHERE id = :id
            """
        ),
        {"w": winner_id, "id": challenge_id},
    )
    if winner_id is not None:
        await db.execute(
            text("UPDATE users SET total_xp = total_xp + :xp WHERE id = :u"),
            {"xp": CHALLENGE_WIN_XP, "u": winner_id},
        )
