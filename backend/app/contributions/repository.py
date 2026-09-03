from __future__ import annotations

import json

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from ..content.schemas import SUPPORTED_LANGS
from .schemas import ContributionCreate

_CONTRIBUTION_DIFFICULTY = "medium"

# Flat XP bonus for a contribution that an admin promotes to 'live'. Reward
# fires once, from app/content/routes.py's review endpoint — not here.
CONTRIBUTION_APPROVAL_XP = 50


async def create_contribution(db: AsyncSession, user_id: str, data: ContributionCreate) -> dict:
    """Insert a player-submitted question as a public draft (is_private=FALSE,
    no owner_teacher_id) — it joins the same public live pick pool as any
    admin-authored question once a reviewer promotes it, unlike teacher
    questions which stay private to their class."""
    prompt = {lang: data.prompt for lang in SUPPORTED_LANGS}
    options = {lang: data.options for lang in SUPPORTED_LANGS}
    row = (
        await db.execute(
            text(
                """
                INSERT INTO questions
                    (category_id, difficulty, prompt, options, correct_index,
                     review_state, is_private, created_by)
                VALUES
                    (:category_id, CAST(:difficulty AS difficulty_level),
                     CAST(:prompt AS jsonb), CAST(:options AS jsonb),
                     :correct_index, 'draft', FALSE, :user_id)
                RETURNING id, category_id, difficulty, review_state,
                          prompt, options, correct_index
                """
            ),
            {
                "category_id": str(data.category_id),
                "difficulty": _CONTRIBUTION_DIFFICULTY,
                "prompt": json.dumps(prompt),
                "options": json.dumps(options),
                "correct_index": data.correct_index,
                "user_id": user_id,
            },
        )
    ).mappings().one()
    return dict(row)


async def list_my_contributions(db: AsyncSession, user_id: str) -> list[dict]:
    rows = (
        await db.execute(
            text(
                """
                SELECT id, category_id, difficulty::text AS difficulty,
                       review_state, prompt, options, correct_index
                FROM questions
                WHERE created_by = :u
                ORDER BY created_at DESC
                """
            ),
            {"u": user_id},
        )
    ).mappings().all()
    return [dict(r) for r in rows]


async def award_approval_xp(db: AsyncSession, user_id: str) -> None:
    await db.execute(
        text("UPDATE users SET total_xp = total_xp + :xp WHERE id = :u"),
        {"xp": CONTRIBUTION_APPROVAL_XP, "u": user_id},
    )
