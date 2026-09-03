from __future__ import annotations

from uuid import UUID

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession


async def join_class(db: AsyncSession, student_id: str, join_code: str) -> dict | None:
    cls = (
        await db.execute(
            text("SELECT id, name FROM classes WHERE join_code = :code"),
            {"code": join_code.strip().upper()},
        )
    ).mappings().first()
    if cls is None:
        return None
    await db.execute(
        text(
            """
            INSERT INTO class_students (class_id, student_id)
            VALUES (:c, :s)
            ON CONFLICT (class_id, student_id) DO NOTHING
            """
        ),
        {"c": str(cls["id"]), "s": student_id},
    )
    return {"class_id": cls["id"], "class_name": cls["name"]}


async def list_assigned_quizzes(db: AsyncSession, student_id: str) -> list[dict]:
    rows = (
        await db.execute(
            text(
                """
                SELECT tq.id AS quiz_id, tq.title, c.name AS class_name,
                       count(tqq.question_id) AS question_count,
                       COALESCE(a.status, 'not_started') AS attempt_status,
                       a.score
                FROM class_students cs
                JOIN classes c ON c.id = cs.class_id
                JOIN teacher_quizzes tq ON tq.class_id = cs.class_id AND tq.status = 'published'
                LEFT JOIN teacher_quiz_questions tqq ON tqq.teacher_quiz_id = tq.id
                LEFT JOIN teacher_quiz_attempts a
                       ON a.teacher_quiz_id = tq.id AND a.student_id = cs.student_id
                WHERE cs.student_id = :s
                GROUP BY tq.id, c.name, a.status, a.score
                ORDER BY tq.created_at DESC
                """
            ),
            {"s": student_id},
        )
    ).mappings().all()
    return [dict(r) for r in rows]


async def get_published_quiz_for_student(
    db: AsyncSession, student_id: str, quiz_id: UUID
) -> dict | None:
    """The quiz, only if published AND the student belongs to its class."""
    row = (
        await db.execute(
            text(
                """
                SELECT tq.id, tq.title, tq.time_limit_ms
                FROM teacher_quizzes tq
                JOIN class_students cs
                     ON cs.class_id = tq.class_id AND cs.student_id = :s
                WHERE tq.id = :q AND tq.status = 'published'
                """
            ),
            {"s": student_id, "q": str(quiz_id)},
        )
    ).mappings().first()
    if row is None:
        return None
    total = (
        await db.execute(
            text("SELECT count(*) FROM teacher_quiz_questions WHERE teacher_quiz_id = :q"),
            {"q": str(quiz_id)},
        )
    ).first()
    return {**dict(row), "total_questions": int(total[0]) if total else 0}


async def get_or_create_attempt(
    db: AsyncSession, student_id: str, quiz_id: UUID, total_questions: int
) -> dict:
    await db.execute(
        text(
            """
            INSERT INTO teacher_quiz_attempts (teacher_quiz_id, student_id, total_questions)
            VALUES (:q, :s, :n)
            ON CONFLICT (teacher_quiz_id, student_id) DO NOTHING
            """
        ),
        {"q": str(quiz_id), "s": student_id, "n": total_questions},
    )
    row = (
        await db.execute(
            text(
                """
                SELECT id, status, score, correct_count, total_questions
                FROM teacher_quiz_attempts
                WHERE teacher_quiz_id = :q AND student_id = :s
                """
            ),
            {"q": str(quiz_id), "s": student_id},
        )
    ).mappings().one()
    return dict(row)


async def get_next_question(db: AsyncSession, quiz_id: UUID, attempt_id: UUID, lang: str) -> dict | None:
    """The first not-yet-answered question in order_no order."""
    row = (
        await db.execute(
            text(
                """
                SELECT q.id, q.prompt, q.options, tqq.order_no
                FROM teacher_quiz_questions tqq
                JOIN questions q ON q.id = tqq.question_id
                WHERE tqq.teacher_quiz_id = :q
                  AND NOT EXISTS (
                      SELECT 1 FROM teacher_quiz_answers a
                      WHERE a.attempt_id = :a AND a.question_id = tqq.question_id
                  )
                ORDER BY tqq.order_no
                LIMIT 1
                """
            ),
            {"q": str(quiz_id), "a": str(attempt_id)},
        )
    ).mappings().first()
    if row is None:
        return None
    options = row["options"].get(lang) or row["options"]["en"]
    prompt = row["prompt"].get(lang) or row["prompt"]["en"]
    return {
        "question_id": row["id"],
        "prompt": prompt,
        "options": options,
        "order_no": row["order_no"],
    }


async def question_in_quiz(db: AsyncSession, quiz_id: UUID, question_id: UUID) -> dict | None:
    row = (
        await db.execute(
            text(
                """
                SELECT q.id, q.difficulty::text AS difficulty, q.options, q.correct_index
                FROM teacher_quiz_questions tqq
                JOIN questions q ON q.id = tqq.question_id
                WHERE tqq.teacher_quiz_id = :quiz AND tqq.question_id = :question
                """
            ),
            {"quiz": str(quiz_id), "question": str(question_id)},
        )
    ).mappings().first()
    return dict(row) if row else None


async def get_existing_answer(db: AsyncSession, attempt_id: UUID, question_id: UUID) -> dict | None:
    row = (
        await db.execute(
            text(
                """
                SELECT is_correct, points_awarded
                FROM teacher_quiz_answers
                WHERE attempt_id = :a AND question_id = :q
                """
            ),
            {"a": str(attempt_id), "q": str(question_id)},
        )
    ).mappings().first()
    return dict(row) if row else None


async def record_answer(
    db: AsyncSession,
    *,
    attempt_id: UUID,
    question_id: UUID,
    chosen_index: int | None,
    is_correct: bool,
    points_awarded: int,
) -> bool:
    """Insert the answer (idempotent via PK(attempt_id, question_id)), update the
    attempt's running score, and mark it completed once every question is
    answered. Returns whether the quiz is now complete."""
    await db.execute(
        text(
            """
            INSERT INTO teacher_quiz_answers
                (attempt_id, question_id, chosen_index, is_correct, points_awarded)
            VALUES (:a, :q, :c, :ok, :pts)
            ON CONFLICT (attempt_id, question_id) DO NOTHING
            """
        ),
        {
            "a": str(attempt_id),
            "q": str(question_id),
            "c": chosen_index,
            "ok": is_correct,
            "pts": points_awarded,
        },
    )
    await db.execute(
        text(
            """
            UPDATE teacher_quiz_attempts
            SET score = (SELECT COALESCE(SUM(points_awarded), 0) FROM teacher_quiz_answers WHERE attempt_id = :a),
                correct_count = (SELECT count(*) FROM teacher_quiz_answers WHERE attempt_id = :a AND is_correct = TRUE)
            WHERE id = :a
            """
        ),
        {"a": str(attempt_id)},
    )
    row = (
        await db.execute(
            text(
                """
                SELECT total_questions,
                       (SELECT count(*) FROM teacher_quiz_answers WHERE attempt_id = :a) AS answered
                FROM teacher_quiz_attempts WHERE id = :a
                """
            ),
            {"a": str(attempt_id)},
        )
    ).mappings().one()
    complete = row["answered"] >= row["total_questions"]
    if complete:
        await db.execute(
            text(
                """
                UPDATE teacher_quiz_attempts
                SET status = 'completed', completed_at = now()
                WHERE id = :a AND status != 'completed'
                """
            ),
            {"a": str(attempt_id)},
        )
    return complete


async def get_result(db: AsyncSession, student_id: str, quiz_id: UUID) -> dict | None:
    row = (
        await db.execute(
            text(
                """
                SELECT tq.title, a.score, a.correct_count, a.total_questions
                FROM teacher_quiz_attempts a
                JOIN teacher_quizzes tq ON tq.id = a.teacher_quiz_id
                WHERE a.teacher_quiz_id = :q AND a.student_id = :s AND a.status = 'completed'
                """
            ),
            {"q": str(quiz_id), "s": student_id},
        )
    ).mappings().first()
    return dict(row) if row else None
