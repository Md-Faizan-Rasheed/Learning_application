from __future__ import annotations

from uuid import UUID

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession


async def get_or_create_practice_user(db: AsyncSession) -> str:
    """A single shared practice user for Sprint 1 (before real auth/matches).
    TODO(auth-epic): replace with the authenticated user."""
    row = (
        await db.execute(
            text("SELECT id FROM users WHERE display_name = 'practice-user' LIMIT 1")
        )
    ).first()
    if row:
        return str(row[0])
    row = (
        await db.execute(
            text(
                """
                INSERT INTO users (role, display_name, gender)
                VALUES ('player', 'practice-user', 'male')
                RETURNING id
                """
            )
        )
    ).first()
    return str(row[0])


async def pick_live_question(db: AsyncSession, difficulty: str | None) -> dict | None:
    """Pick one LIVE question in an ACTIVE category. review_state gate enforced
    here so unreviewed content can never reach a player."""
    q = """
        SELECT q.id, q.difficulty::text AS difficulty, q.prompt, q.options,
               q.correct_index
        FROM questions q
        JOIN categories c ON c.id = q.category_id
        WHERE q.review_state = 'live' AND c.is_active = TRUE
    """
    params: dict = {}
    if difficulty:
        q += " AND q.difficulty = CAST(:difficulty AS difficulty_level)"
        params["difficulty"] = difficulty
    q += " ORDER BY random() LIMIT 1"
    row = (await db.execute(text(q), params)).mappings().first()
    return dict(row) if row else None


async def create_practice_match(db: AsyncSession, difficulty: str) -> str:
    row = (
        await db.execute(
            text(
                """
                INSERT INTO matches (difficulty, status, started_at)
                VALUES (CAST(:difficulty AS difficulty_level), 'active', now())
                RETURNING id
                """
            ),
            {"difficulty": difficulty},
        )
    ).first()
    match_id = str(row[0])
    user_id = await get_or_create_practice_user(db)
    await db.execute(
        text(
            """
            INSERT INTO match_players (match_id, user_id)
            VALUES (:m, :u)
            ON CONFLICT (match_id, user_id) DO NOTHING
            """
        ),
        {"m": match_id, "u": user_id},
    )
    return match_id


async def get_question_for_grading(db: AsyncSession, question_id: UUID) -> dict | None:
    row = (
        await db.execute(
            text(
                """
                SELECT id, difficulty::text AS difficulty, options, correct_index
                FROM questions WHERE id = :id AND review_state = 'live'
                """
            ),
            {"id": str(question_id)},
        )
    ).mappings().first()
    return dict(row) if row else None


async def get_existing_attempt(
    db: AsyncSession, match_id: UUID, question_id: UUID, user_id: str
) -> dict | None:
    """Idempotency read: has this user already answered this question in this match?"""
    row = (
        await db.execute(
            text(
                """
                SELECT is_correct, points_awarded
                FROM attempts
                WHERE match_id = :m AND question_id = :q AND user_id = :u
                """
            ),
            {"m": str(match_id), "q": str(question_id), "u": user_id},
        )
    ).mappings().first()
    return dict(row) if row else None


async def insert_attempt(
    db: AsyncSession,
    *,
    match_id: UUID,
    question_id: UUID,
    user_id: str,
    chosen_answer: str | None,
    is_correct: bool,
    response_ms: int | None,
    points_awarded: int,
) -> None:
    """Insert the attempt. The UNIQUE(match_id, question_id, user_id) constraint
    is the data-layer idempotency guard; ON CONFLICT makes a retry a no-op."""
    await db.execute(
        text(
            """
            INSERT INTO attempts
                (match_id, question_id, user_id, chosen_answer,
                 is_correct, response_ms, points_awarded)
            VALUES (:m, :q, :u, :chosen, :ok, :ms, :pts)
            ON CONFLICT (match_id, question_id, user_id) DO NOTHING
            """
        ),
        {
            "m": str(match_id),
            "q": str(question_id),
            "u": user_id,
            "chosen": chosen_answer,
            "ok": is_correct,
            "ms": response_ms,
            "pts": points_awarded,
        },
    )


async def create_db_match(db: AsyncSession, difficulty: str) -> str:
    """Create a real matches row (durable record) and return its id."""
    row = (
        await db.execute(
            text(
                """
                INSERT INTO matches (difficulty, status, started_at)
                VALUES (CAST(:d AS difficulty_level), 'active', now())
                RETURNING id
                """
            ),
            {"d": difficulty},
        )
    ).first()
    return str(row[0])


async def create_db_user(db: AsyncSession, display_name: str, gender: str = "male") -> str:
    """Create a real users row for a joining human. TODO(auth-epic): replace
    with the authenticated user instead of creating one per join."""
    row = (
        await db.execute(
            text(
                """
                INSERT INTO users (role, display_name, gender)
                VALUES ('player', :n, CAST(:g AS gender_type))
                RETURNING id
                """
            ),
            {"n": display_name, "g": gender},
        )
    ).first()
    return str(row[0])


async def add_match_player(db: AsyncSession, match_id: str, user_id: str) -> None:
    await db.execute(
        text(
            """
            INSERT INTO match_players (match_id, user_id)
            VALUES (:m, :u) ON CONFLICT (match_id, user_id) DO NOTHING
            """
        ),
        {"m": match_id, "u": user_id},
    )


async def set_match_player_result(
    db: AsyncSession, *, match_id: str, user_id: str, final_score: int, placement: int
) -> None:
    """Write a player's final score + placement onto their match_players row."""
    await db.execute(
        text(
            """
            UPDATE match_players
            SET final_score = :s, placement = :p
            WHERE match_id = :m AND user_id = :u
            """
        ),
        {"s": final_score, "p": placement, "m": match_id, "u": user_id},
    )