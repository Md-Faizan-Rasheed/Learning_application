from __future__ import annotations

import json
from uuid import UUID

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from .schemas import CategoryCreate, CategoryUpdate, QuestionCreate, QuestionUpdate


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


async def update_category(db: AsyncSession, category_id: UUID, data: CategoryUpdate) -> dict | None:
    row = (
        await db.execute(
            text(
                """
                UPDATE categories
                SET display_name = COALESCE(:display_name, display_name),
                    description = COALESCE(:description, description),
                    is_active = COALESCE(:is_active, is_active)
                WHERE id = :id
                RETURNING id, slug, display_name, is_active
                """
            ),
            {
                "id": str(category_id),
                "display_name": data.display_name,
                "description": data.description,
                "is_active": data.is_active,
            },
        )
    ).mappings().first()
    return dict(row) if row else None


async def find_category(db: AsyncSession, slug_or_id: str) -> dict | None:
    """Resolve a category by UUID (if it parses as one) or by slug — used by
    bulk import, where content authors typically know the slug, not the id."""
    try:
        UUID(slug_or_id)
        row = (
            await db.execute(
                text("SELECT id, slug, display_name, is_active FROM categories WHERE id = :v"),
                {"v": slug_or_id},
            )
        ).mappings().first()
    except ValueError:
        row = (
            await db.execute(
                text("SELECT id, slug, display_name, is_active FROM categories WHERE slug = :v"),
                {"v": slug_or_id},
            )
        ).mappings().first()
    return dict(row) if row else None


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


async def get_review_state_and_owner(db: AsyncSession, question_id: UUID) -> dict | None:
    """Single-purpose read used only to detect a genuine draft/reviewed ->
    live transition for the contribution-reward hook in routes.py — kept
    separate from get_question so that function's contract (admin editor)
    doesn't grow fields it doesn't need."""
    row = (
        await db.execute(
            text("SELECT review_state, created_by FROM questions WHERE id = :id"),
            {"id": str(question_id)},
        )
    ).mappings().first()
    return dict(row) if row else None


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


async def list_questions(
    db: AsyncSession,
    category_id: UUID | None = None,
    review_state: str | None = None,
    search: str | None = None,
    limit: int = 50,
    offset: int = 0,
) -> list[dict]:
    clauses = []
    params: dict = {"limit": limit, "offset": offset}
    if category_id is not None:
        clauses.append("category_id = :category_id")
        params["category_id"] = str(category_id)
    if review_state is not None:
        clauses.append("review_state = CAST(:review_state AS review_state)")
        params["review_state"] = review_state
    if search:
        clauses.append("prompt->>'en' ILIKE :search")
        params["search"] = f"%{search}%"
    where = f"WHERE {' AND '.join(clauses)}" if clauses else ""
    rows = (
        await db.execute(
            text(
                f"""
                SELECT id, category_id, difficulty, review_state,
                       prompt->>'en' AS prompt_preview,
                       to_char(updated_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS updated_at
                FROM questions
                {where}
                ORDER BY updated_at DESC
                LIMIT :limit OFFSET :offset
                """
            ),
            params,
        )
    ).mappings().all()
    return [dict(r) for r in rows]


async def get_question(db: AsyncSession, question_id: UUID) -> dict | None:
    row = (
        await db.execute(
            text(
                """
                SELECT id, category_id, difficulty, review_state,
                       prompt, options, correct_index, source
                FROM questions
                WHERE id = :id
                """
            ),
            {"id": str(question_id)},
        )
    ).mappings().first()
    return dict(row) if row else None


async def update_question(db: AsyncSession, question_id: UUID, data: QuestionUpdate) -> dict | None:
    row = (
        await db.execute(
            text(
                """
                UPDATE questions
                SET category_id = COALESCE(:category_id, category_id),
                    difficulty = COALESCE(CAST(:difficulty AS difficulty_level), difficulty),
                    prompt = COALESCE(CAST(:prompt AS jsonb), prompt),
                    options = COALESCE(CAST(:options AS jsonb), options),
                    correct_index = COALESCE(:correct_index, correct_index),
                    source = COALESCE(:source, source)
                WHERE id = :id
                RETURNING id, category_id, difficulty, review_state,
                          prompt, options, correct_index, source
                """
            ),
            {
                "id": str(question_id),
                "category_id": str(data.category_id) if data.category_id else None,
                "difficulty": data.difficulty,
                "prompt": json.dumps(data.prompt) if data.prompt is not None else None,
                "options": json.dumps(data.options) if data.options is not None else None,
                "correct_index": data.correct_index,
                "source": data.source,
            },
        )
    ).mappings().first()
    return dict(row) if row else None


async def delete_question(db: AsyncSession, question_id: UUID) -> bool:
    result = await db.execute(text("DELETE FROM questions WHERE id = :id"), {"id": str(question_id)})
    return result.rowcount > 0