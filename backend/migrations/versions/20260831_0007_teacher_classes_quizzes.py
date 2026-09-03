"""teacher classes and quizzes

Adds a 'teacher' role plus the schema for the teacher-quiz vertical slice:
teachers create classes (students join via a short code), build quizzes
from a mix of the public question bank and their own private questions,
assign a quiz to a class, and students take it with server-graded,
idempotent answer submission (same pattern as the existing `attempts`
table used by practice/multiplayer).

Revision ID: 0007_teacher_quizzes
Revises: 0006_daily_quests
Create Date: 2026-08-31
"""
from alembic import op

revision = "0007_teacher_quizzes"
down_revision = "0006_daily_quests"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ---------- users: new role ----------
    # Safe inside this migration's transaction as long as 'teacher' isn't
    # used by any DML in this same migration (Postgres 12+ requirement).
    op.execute("ALTER TYPE user_role ADD VALUE 'teacher'")

    # ---------- questions: private, teacher-authored content ----------
    # Lets a teacher author a question that bypasses scholar review (it's
    # inserted directly as review_state='live') without ever entering the
    # public random-pick pool used by practice/multiplayer.
    op.execute("ALTER TABLE questions ADD COLUMN is_private BOOLEAN NOT NULL DEFAULT FALSE")
    op.execute(
        "ALTER TABLE questions ADD COLUMN owner_teacher_id UUID "
        "REFERENCES users (id) ON DELETE CASCADE"
    )
    op.execute("DROP INDEX IF EXISTS idx_questions_pick")
    op.execute(
        "CREATE INDEX idx_questions_pick ON questions (difficulty, category_id) "
        "WHERE review_state = 'live' AND is_private = FALSE"
    )

    # ---------- classes ----------
    op.execute(
        """
        CREATE TABLE classes (
            id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            teacher_id  UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
            name        TEXT NOT NULL,
            join_code   TEXT NOT NULL UNIQUE,
            created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
            updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
        )
        """
    )
    op.execute(
        "CREATE TRIGGER trg_classes_updated BEFORE UPDATE ON classes "
        "FOR EACH ROW EXECUTE FUNCTION set_updated_at()"
    )
    op.execute("CREATE INDEX idx_classes_teacher ON classes (teacher_id)")

    # ---------- class_students ----------
    op.execute(
        """
        CREATE TABLE class_students (
            class_id    UUID NOT NULL REFERENCES classes (id) ON DELETE CASCADE,
            student_id  UUID NOT NULL REFERENCES users (id)   ON DELETE CASCADE,
            joined_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
            PRIMARY KEY (class_id, student_id)
        )
        """
    )
    op.execute("CREATE INDEX idx_class_students_student ON class_students (student_id)")

    # ---------- teacher_quizzes ----------
    op.execute(
        """
        CREATE TABLE teacher_quizzes (
            id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            teacher_id     UUID NOT NULL REFERENCES users (id)   ON DELETE CASCADE,
            class_id       UUID NOT NULL REFERENCES classes (id) ON DELETE CASCADE,
            title          TEXT NOT NULL,
            time_limit_ms  INTEGER NOT NULL DEFAULT 20000,
            status         TEXT NOT NULL DEFAULT 'draft'
                           CHECK (status IN ('draft', 'published', 'closed')),
            created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
            updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
        )
        """
    )
    op.execute(
        "CREATE TRIGGER trg_teacher_quizzes_updated BEFORE UPDATE ON teacher_quizzes "
        "FOR EACH ROW EXECUTE FUNCTION set_updated_at()"
    )
    op.execute("CREATE INDEX idx_teacher_quizzes_class ON teacher_quizzes (class_id)")
    op.execute("CREATE INDEX idx_teacher_quizzes_teacher ON teacher_quizzes (teacher_id)")

    # ---------- teacher_quiz_questions ----------
    op.execute(
        """
        CREATE TABLE teacher_quiz_questions (
            teacher_quiz_id  UUID NOT NULL REFERENCES teacher_quizzes (id) ON DELETE CASCADE,
            question_id      UUID NOT NULL REFERENCES questions (id)       ON DELETE RESTRICT,
            order_no         SMALLINT NOT NULL,
            PRIMARY KEY (teacher_quiz_id, question_id),
            UNIQUE (teacher_quiz_id, order_no)
        )
        """
    )

    # ---------- teacher_quiz_attempts ----------
    op.execute(
        """
        CREATE TABLE teacher_quiz_attempts (
            id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            teacher_quiz_id   UUID NOT NULL REFERENCES teacher_quizzes (id) ON DELETE CASCADE,
            student_id        UUID NOT NULL REFERENCES users (id)          ON DELETE CASCADE,
            status            TEXT NOT NULL DEFAULT 'in_progress'
                              CHECK (status IN ('in_progress', 'completed')),
            score             INTEGER NOT NULL DEFAULT 0,
            correct_count     INTEGER NOT NULL DEFAULT 0,
            total_questions   SMALLINT NOT NULL,
            started_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
            completed_at      TIMESTAMPTZ,
            UNIQUE (teacher_quiz_id, student_id)
        )
        """
    )
    op.execute("CREATE INDEX idx_tq_attempts_student ON teacher_quiz_attempts (student_id)")

    # ---------- teacher_quiz_answers ----------
    # UNIQUE (attempt_id, question_id) is the idempotency guard for answer
    # submission, mirroring UNIQUE(match_id, question_id, user_id) on `attempts`.
    op.execute(
        """
        CREATE TABLE teacher_quiz_answers (
            attempt_id       UUID NOT NULL REFERENCES teacher_quiz_attempts (id) ON DELETE CASCADE,
            question_id      UUID NOT NULL REFERENCES questions (id)             ON DELETE RESTRICT,
            chosen_index     SMALLINT,
            is_correct       BOOLEAN NOT NULL DEFAULT FALSE,
            points_awarded   INTEGER NOT NULL DEFAULT 0,
            created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
            PRIMARY KEY (attempt_id, question_id)
        )
        """
    )


def downgrade() -> None:
    op.execute("DROP TABLE IF EXISTS teacher_quiz_answers")
    op.execute("DROP TABLE IF EXISTS teacher_quiz_attempts")
    op.execute("DROP TABLE IF EXISTS teacher_quiz_questions")
    op.execute("DROP TABLE IF EXISTS teacher_quizzes")
    op.execute("DROP TABLE IF EXISTS class_students")
    op.execute("DROP TABLE IF EXISTS classes")

    op.execute("DROP INDEX IF EXISTS idx_questions_pick")
    op.execute("ALTER TABLE questions DROP COLUMN IF EXISTS owner_teacher_id")
    op.execute("ALTER TABLE questions DROP COLUMN IF EXISTS is_private")
    op.execute(
        "CREATE INDEX idx_questions_pick ON questions (difficulty, category_id) "
        "WHERE review_state = 'live'"
    )

    # Postgres cannot drop a single enum value in place. Removing 'teacher'
    # from user_role would require recreating the type (and remapping every
    # dependent column/constraint) and is only safe if no row uses it — left
    # as a manual step rather than an automatic (and risky) downgrade here.
