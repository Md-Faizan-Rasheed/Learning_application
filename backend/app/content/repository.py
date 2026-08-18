from __future__ import annotations

from uuid import UUID

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from .schemas import CategoryCreate, QuestionCreate


async def create_category(db: AsyncSession, data: CategoryCreate) -> dict:
    row = (
        await db.execute(
            text(
                """
                INSERT INTO categories (slug, display_name, description)
                VALUES (:slug, :display_name, :description)
                RETURNING id, slug, display_name, is_active
                """
            ),
            data.model_dump(),
        )
    ).mappings().one()
    return dict(row)


async def list_categories(db: AsyncSession, active_only: bool = True) -> list[dict]:
    q = "SELECT id, slug, display_name, is_active FROM categories"
    if active_only:
        q += " WHERE is_active = TRUE"
    q += " ORDER BY display_name"
    rows = (await db.execute(text(q))).mappings().all()
    return [dict(r) for r in rows]


async def category_exists(db: AsyncSession, category_id: UUID) -> bool:
    row = (
        await db.execute(
            text("SELECT 1 FROM categories WHERE id = :id"),
            {"id": str(category_id)},
        )
    ).first()
    return row is not None


async def create_question(db: AsyncSession, data: QuestionCreate) -> dict:
    """Insert a question. It starts in review_state='draft' (schema default) —
    it will NOT be served to players until a reviewer promotes it to 'live'."""
    import json

    row = (
        await db.execute(
            text(
                """
                INSERT INTO questions
                    (category_id, difficulty, prompt, options, correct_index, source)
                VALUES
                    (:category_id, CAST(:difficulty AS difficulty_level),
                     CAST(:prompt AS jsonb), CAST(:options AS jsonb),
                     :correct_index, :source)
                RETURNING id, category_id, difficulty, review_state,
                          prompt, options, correct_index, source
                """
            ),
            {
                "category_id": str(data.category_id),
                "difficulty": data.difficulty,
                "prompt": json.dumps(data.prompt),
                "options": json.dumps(data.options),
                "correct_index": data.correct_index,
                "source": data.source,
            },
        )
    ).mappings().one()
    return dict(row)


async def set_review_state(db: AsyncSession, question_id: UUID, state: str) -> dict | None:
    row = (
        await db.execute(
            text(
                """
                UPDATE questions
                SET review_state = CAST(:state AS review_state),
                    reviewed_at = now()
                WHERE id = :id
                RETURNING id, category_id, difficulty, review_state,
                          prompt, options, correct_index, source
                """
            ),
            {"id": str(question_id), "state": state},
        )
    ).mappings().first()
    return dict(row) if row else None