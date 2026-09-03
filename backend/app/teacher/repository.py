from __future__ import annotations

import json
import secrets
import string
from uuid import UUID

from sqlalchemy import text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..content.schemas import SUPPORTED_LANGS
from .schemas import TeacherQuestionCreate, QuizCreate

_CODE_ALPHABET = string.ascii_uppercase + string.digits
_TEACHER_QUESTION_DIFFICULTY = "medium"


def _generate_join_code(length: int = 6) -> str:
    return "".join(secrets.choice(_CODE_ALPHABET) for _ in range(length))


async def create_class(db: AsyncSession, *, teacher_id: str, name: str) -> dict:
    """Insert a class with a freshly generated unique join code, retrying on
    the rare collision (UNIQUE constraint on join_code)."""
    for _ in range(5):
        code = _generate_join_code()
        try:
            row = (
                await db.execute(
                    text(
                        """
                        INSERT INTO classes (teacher_id, name, join_code)
                        VALUES (:t, :n, :c)
                        RETURNING id, name, join_code
                        """
                    ),
                    {"t": teacher_id, "n": name, "c": code},
                )
            ).mappings().one()
            return {**dict(row), "student_count": 0}
        except IntegrityError:
            await db.rollback()
            continue
    raise RuntimeError("could not generate a unique join code")


async def list_classes(db: AsyncSession, teacher_id: str) -> list[dict]:
    rows = (
        await db.execute(
            text(
                """
                SELECT c.id, c.name, c.join_code,
                       count(cs.student_id) AS student_count
                FROM classes c
                LEFT JOIN class_students cs ON cs.class_id = c.id
                WHERE c.teacher_id = :t
                GROUP BY c.id
                ORDER BY c.created_at DESC
                """
            ),
            {"t": teacher_id},
        )
    ).mappings().all()
    return [dict(r) for r in rows]


async def get_class(db: AsyncSession, teacher_id: str, class_id: UUID) -> dict | None:
    cls = (
        await db.execute(
            text(
                "SELECT id, name, join_code FROM classes WHERE id = :id AND teacher_id = :t"
            ),
            {"id": str(class_id), "t": teacher_id},
        )
    ).mappings().first()
    if cls is None:
        return None
    students = (
        await db.execute(
            text(
                """
                SELECT u.id AS student_id, u.display_name
                FROM class_students cs
                JOIN users u ON u.id = cs.student_id
                WHERE cs.class_id = :c
                ORDER BY u.display_name
                """
            ),
            {"c": str(class_id)},
        )
    ).mappings().all()
    return {**dict(cls), "students": [dict(s) for s in students]}


async def class_belongs_to_teacher(db: AsyncSession, teacher_id: str, class_id: UUID) -> bool:
    row = (
        await db.execute(
            text("SELECT 1 FROM classes WHERE id = :id AND teacher_id = :t"),
            {"id": str(class_id), "t": teacher_id},
        )
    ).first()
    return row is not None


async def delete_class(db: AsyncSession, teacher_id: str, class_id: UUID) -> bool:
    result = await db.execute(
        text("DELETE FROM classes WHERE id = :id AND teacher_id = :t"),
        {"id": str(class_id), "t": teacher_id},
    )
    return result.rowcount > 0


async def create_teacher_question(db: AsyncSession, teacher_id: str, data: TeacherQuestionCreate) -> dict:
    """Insert a teacher's own question directly as live+private: it skips the
    scholar-review pipeline but is excluded from the public random-pick pool
    (idx_questions_pick filters on is_private = FALSE).

    Teacher questions are authored in a single language (no translation
    step, unlike the admin bank) — the same text is stored under every
    SUPPORTED_LANGS key so it still fits the shared per-language JSONB
    columns and is served as-is regardless of the student's app language."""
    prompt = {lang: data.prompt for lang in SUPPORTED_LANGS}
    options = {lang: data.options for lang in SUPPORTED_LANGS}
    row = (
        await db.execute(
            text(
                """
                INSERT INTO questions
                    (category_id, difficulty, prompt, options, correct_index,
                     review_state, is_private, owner_teacher_id)
                VALUES
                    (:category_id, CAST(:difficulty AS difficulty_level),
                     CAST(:prompt AS jsonb), CAST(:options AS jsonb),
                     :correct_index, 'live', TRUE, :teacher_id)
                RETURNING id, category_id, difficulty, prompt, options, correct_index, source
                """
            ),
            {
                "category_id": str(data.category_id),
                "difficulty": _TEACHER_QUESTION_DIFFICULTY,
                "prompt": json.dumps(prompt),
                "options": json.dumps(options),
                "correct_index": data.correct_index,
                "teacher_id": teacher_id,
            },
        )
    ).mappings().one()
    return dict(row)


async def create_ai_question(
    db: AsyncSession,
    teacher_id: str,
    category_id: UUID,
    prompt: str,
    options: list[str],
    correct_index: int,
) -> dict:
    """Like create_teacher_question, but inserted as 'draft' instead of
    'live' — AI-extracted questions need an explicit teacher confirm
    (see confirm_question) before a quiz containing them can be published."""
    prompt_map = {lang: prompt for lang in SUPPORTED_LANGS}
    options_map = {lang: options for lang in SUPPORTED_LANGS}
    row = (
        await db.execute(
            text(
                """
                INSERT INTO questions
                    (category_id, difficulty, prompt, options, correct_index,
                     review_state, is_private, owner_teacher_id)
                VALUES
                    (:category_id, CAST(:difficulty AS difficulty_level),
                     CAST(:prompt AS jsonb), CAST(:options AS jsonb),
                     :correct_index, 'draft', TRUE, :teacher_id)
                RETURNING id, category_id, difficulty, prompt, options, correct_index, source
                """
            ),
            {
                "category_id": str(category_id),
                "difficulty": _TEACHER_QUESTION_DIFFICULTY,
                "prompt": json.dumps(prompt_map),
                "options": json.dumps(options_map),
                "correct_index": correct_index,
                "teacher_id": teacher_id,
            },
        )
    ).mappings().one()
    return dict(row)


async def confirm_question(db: AsyncSession, teacher_id: str, question_id: UUID) -> dict | None:
    """Promote a teacher's own AI-drafted question to 'live' once they've
    reviewed it. Ownership and draft-state are enforced in the WHERE clause
    rather than a separate check."""
    row = (
        await db.execute(
            text(
                """
                UPDATE questions
                SET review_state = 'live'
                WHERE id = :id AND owner_teacher_id = :t AND review_state = 'draft'
                RETURNING id, category_id, difficulty, prompt, options, correct_index, source
                """
            ),
            {"id": str(question_id), "t": teacher_id},
        )
    ).mappings().first()
    return dict(row) if row else None


async def quiz_has_unconfirmed_drafts(db: AsyncSession, teacher_id: str, quiz_id: UUID) -> int:
    """Count of this quiz's questions still awaiting teacher confirmation
    (AI-imported and not yet reviewed). Scoped to teacher_id so a teacher
    can't probe another teacher's quiz via this check."""
    row = (
        await db.execute(
            text(
                """
                SELECT count(*) FROM teacher_quiz_questions tqq
                JOIN questions q ON q.id = tqq.question_id
                JOIN teacher_quizzes tz ON tz.id = tqq.teacher_quiz_id
                WHERE tqq.teacher_quiz_id = :q AND tz.teacher_id = :t AND q.review_state = 'draft'
                """
            ),
            {"q": str(quiz_id), "t": teacher_id},
        )
    ).first()
    return int(row[0]) if row else 0


async def list_teacher_questions(db: AsyncSession, teacher_id: str) -> list[dict]:
    rows = (
        await db.execute(
            text(
                """
                SELECT id, category_id, difficulty::text AS difficulty,
                       prompt, options, correct_index, source
                FROM questions
                WHERE owner_teacher_id = :t
                ORDER BY created_at DESC
                """
            ),
            {"t": teacher_id},
        )
    ).mappings().all()
    return [dict(r) for r in rows]


async def list_bank_questions(
    db: AsyncSession, category_id: UUID | None, difficulty: str | None
) -> list[dict]:
    q = """
        SELECT id, category_id, difficulty::text AS difficulty, prompt, options, correct_index
        FROM questions
        WHERE review_state = 'live' AND is_private = FALSE
    """
    params: dict = {}
    if category_id:
        q += " AND category_id = :cat"
        params["cat"] = str(category_id)
    if difficulty:
        q += " AND difficulty = CAST(:diff AS difficulty_level)"
        params["diff"] = difficulty
    q += " ORDER BY created_at DESC"
    rows = (await db.execute(text(q), params)).mappings().all()
    return [dict(r) for r in rows]


async def question_ids_usable_by_teacher(
    db: AsyncSession, teacher_id: str, question_ids: list[UUID]
) -> bool:
    """True iff every id exists and is either public-live or owned by this teacher."""
    rows = (
        await db.execute(
            text(
                """
                SELECT count(*) FROM questions
                WHERE id = ANY(CAST(:ids AS uuid[]))
                  AND ((review_state = 'live' AND is_private = FALSE)
                       OR owner_teacher_id = :t)
                """
            ),
            {"ids": [str(i) for i in question_ids], "t": teacher_id},
        )
    ).first()
    return int(rows[0]) == len(set(question_ids))


async def create_quiz(db: AsyncSession, teacher_id: str, data: QuizCreate) -> dict:
    row = (
        await db.execute(
            text(
                """
                INSERT INTO teacher_quizzes (teacher_id, class_id, title, time_limit_ms)
                VALUES (:t, :c, :title, :ms)
                RETURNING id, class_id, title, time_limit_ms, status
                """
            ),
            {
                "t": teacher_id,
                "c": str(data.class_id),
                "title": data.title,
                "ms": data.time_limit_ms,
            },
        )
    ).mappings().one()
    quiz_id = str(row["id"])
    for order_no, question_id in enumerate(data.question_ids):
        await db.execute(
            text(
                """
                INSERT INTO teacher_quiz_questions (teacher_quiz_id, question_id, order_no)
                VALUES (:q, :question, :o)
                """
            ),
            {"q": quiz_id, "question": str(question_id), "o": order_no},
        )
    return {**dict(row), "question_count": len(data.question_ids)}


async def publish_quiz(db: AsyncSession, teacher_id: str, quiz_id: UUID) -> dict | None:
    row = (
        await db.execute(
            text(
                """
                UPDATE teacher_quizzes SET status = 'published'
                WHERE id = :id AND teacher_id = :t AND status = 'draft'
                RETURNING id, class_id, title, time_limit_ms, status
                """
            ),
            {"id": str(quiz_id), "t": teacher_id},
        )
    ).mappings().first()
    if row is None:
        return None
    count = await _question_count(db, quiz_id)
    return {**dict(row), "question_count": count}


async def _question_count(db: AsyncSession, quiz_id: UUID | str) -> int:
    row = (
        await db.execute(
            text("SELECT count(*) FROM teacher_quiz_questions WHERE teacher_quiz_id = :q"),
            {"q": str(quiz_id)},
        )
    ).first()
    return int(row[0]) if row else 0


async def list_quizzes(db: AsyncSession, teacher_id: str) -> list[dict]:
    rows = (
        await db.execute(
            text(
                """
                SELECT tq.id, tq.class_id, tq.title, tq.time_limit_ms, tq.status,
                       count(tqq.question_id) AS question_count
                FROM teacher_quizzes tq
                LEFT JOIN teacher_quiz_questions tqq ON tqq.teacher_quiz_id = tq.id
                WHERE tq.teacher_id = :t
                GROUP BY tq.id
                ORDER BY tq.created_at DESC
                """
            ),
            {"t": teacher_id},
        )
    ).mappings().all()
    return [dict(r) for r in rows]


async def get_quiz_owned(db: AsyncSession, teacher_id: str, quiz_id: UUID) -> dict | None:
    row = (
        await db.execute(
            text(
                """
                SELECT id, class_id, title, time_limit_ms, status
                FROM teacher_quizzes WHERE id = :id AND teacher_id = :t
                """
            ),
            {"id": str(quiz_id), "t": teacher_id},
        )
    ).mappings().first()
    if row is None:
        return None
    return {**dict(row), "question_count": await _question_count(db, quiz_id)}


async def get_quiz_results(db: AsyncSession, teacher_id: str, quiz_id: UUID) -> dict | None:
    quiz = await get_quiz_owned(db, teacher_id, quiz_id)
    if quiz is None:
        return None
    rows = (
        await db.execute(
            text(
                """
                SELECT u.id AS student_id, u.display_name,
                       a.status, a.score, a.correct_count, a.total_questions
                FROM class_students cs
                JOIN users u ON u.id = cs.student_id
                LEFT JOIN teacher_quiz_attempts a
                       ON a.student_id = cs.student_id AND a.teacher_quiz_id = :q
                WHERE cs.class_id = :c
                ORDER BY u.display_name
                """
            ),
            {"q": str(quiz_id), "c": str(quiz["class_id"])},
        )
    ).mappings().all()

    students = [
        {
            "student_id": r["student_id"],
            "display_name": r["display_name"],
            "status": r["status"] or "not_started",
            "score": r["score"],
            "correct_count": r["correct_count"],
            "total_questions": r["total_questions"],
        }
        for r in rows
    ]
    completed = [s for s in students if s["status"] == "completed"]
    average = (
        sum(s["score"] for s in completed) / len(completed) if completed else None
    )
    completion_rate = len(completed) / len(students) if students else 0.0
    return {
        "quiz": quiz,
        "students": students,
        "average_score": average,
        "completion_rate": completion_rate,
    }
