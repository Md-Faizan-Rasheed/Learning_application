"""stage 1 foundations

Establishes the Stage 1 schema: users, questions (+ scholar-review gate
and IRT), matches, match_players, match_questions, and attempts (the
keystone that unblocks recap, spaced repetition, IRT calibration, and
analytics).

Revision ID: 0001_stage1
Revises:
Create Date: 2026-08-11
"""
from alembic import op

# revision identifiers, used by Alembic.
revision = "0001_stage1"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ---------- enum types ----------
    op.execute("CREATE TYPE user_role        AS ENUM ('player', 'developer', 'scholar', 'admin')")
    op.execute("CREATE TYPE gender_type      AS ENUM ('male', 'female')")
    op.execute("CREATE TYPE difficulty_level AS ENUM ('easy', 'medium', 'hard')")
    op.execute("CREATE TYPE review_state     AS ENUM ('draft', 'reviewed', 'live')")
    op.execute("CREATE TYPE match_status     AS ENUM ('waiting', 'active', 'completed', 'abandoned')")
    op.execute("CREATE TYPE connection_state AS ENUM ('connected', 'disconnected', 'abandoned', 'bot')")

    # ---------- reusable updated_at trigger ----------
    op.execute(
        """
        CREATE OR REPLACE FUNCTION set_updated_at()
        RETURNS TRIGGER AS $$
        BEGIN
            NEW.updated_at = now();
            RETURN NEW;
        END;
        $$ LANGUAGE plpgsql
        """
    )

    # ---------- users ----------
    op.execute(
        """
        CREATE TABLE users (
            id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            role            user_role        NOT NULL DEFAULT 'player',
            display_name    TEXT             NOT NULL,
            email           TEXT             UNIQUE,
            gender          gender_type,
            difficulty_pref difficulty_level,
            skill_mu        DOUBLE PRECISION NOT NULL DEFAULT 25.0,
            skill_sigma     DOUBLE PRECISION NOT NULL DEFAULT 8.3333333333,
            streak_days     INTEGER          NOT NULL DEFAULT 0,
            streak_freezes  INTEGER          NOT NULL DEFAULT 0,
            last_played_on  DATE,
            created_at      TIMESTAMPTZ      NOT NULL DEFAULT now(),
            updated_at      TIMESTAMPTZ      NOT NULL DEFAULT now(),
            CONSTRAINT players_need_gender
                CHECK (role <> 'player' OR gender IS NOT NULL)
        )
        """
    )
    op.execute(
        "CREATE TRIGGER trg_users_updated BEFORE UPDATE ON users "
        "FOR EACH ROW EXECUTE FUNCTION set_updated_at()"
    )
    op.execute("CREATE INDEX idx_users_role ON users (role)")

    # ---------- questions ----------
    op.execute(
        """
        CREATE TABLE questions (
            id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            prompt          TEXT             NOT NULL,
            difficulty      difficulty_level NOT NULL,
            category        TEXT             NOT NULL,
            options         JSONB            NOT NULL,
            correct_answer  TEXT             NOT NULL,
            source          TEXT,
            review_state    review_state     NOT NULL DEFAULT 'draft',
            created_by      UUID             REFERENCES users (id) ON DELETE SET NULL,
            reviewed_by     UUID             REFERENCES users (id) ON DELETE SET NULL,
            reviewed_at     TIMESTAMPTZ,
            irt_difficulty  DOUBLE PRECISION,
            created_at      TIMESTAMPTZ      NOT NULL DEFAULT now(),
            updated_at      TIMESTAMPTZ      NOT NULL DEFAULT now(),
            CONSTRAINT options_is_array CHECK (jsonb_typeof(options) = 'array')
        )
        """
    )
    op.execute(
        "CREATE TRIGGER trg_questions_updated BEFORE UPDATE ON questions "
        "FOR EACH ROW EXECUTE FUNCTION set_updated_at()"
    )
    op.execute(
        "CREATE INDEX idx_questions_pick ON questions (difficulty, category) "
        "WHERE review_state = 'live'"
    )
    op.execute("CREATE INDEX idx_questions_review ON questions (review_state)")

    # ---------- matches ----------
    op.execute(
        """
        CREATE TABLE matches (
            id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            difficulty  difficulty_level NOT NULL,
            status      match_status     NOT NULL DEFAULT 'waiting',
            started_at  TIMESTAMPTZ,
            ended_at    TIMESTAMPTZ,
            created_at  TIMESTAMPTZ      NOT NULL DEFAULT now()
        )
        """
    )
    op.execute("CREATE INDEX idx_matches_status ON matches (status)")

    # ---------- match_players ----------
    op.execute(
        """
        CREATE TABLE match_players (
            match_id     UUID NOT NULL REFERENCES matches (id) ON DELETE CASCADE,
            user_id      UUID NOT NULL REFERENCES users (id)   ON DELETE CASCADE,
            is_bot       BOOLEAN          NOT NULL DEFAULT FALSE,
            final_score  INTEGER          NOT NULL DEFAULT 0,
            placement    SMALLINT,
            conn_state   connection_state NOT NULL DEFAULT 'connected',
            joined_at    TIMESTAMPTZ      NOT NULL DEFAULT now(),
            PRIMARY KEY (match_id, user_id),
            CONSTRAINT placement_range CHECK (placement IS NULL OR placement BETWEEN 1 AND 4)
        )
        """
    )
    op.execute("CREATE INDEX idx_match_players_user ON match_players (user_id)")

    # ---------- match_questions ----------
    op.execute(
        """
        CREATE TABLE match_questions (
            match_id     UUID NOT NULL REFERENCES matches (id)   ON DELETE CASCADE,
            question_id  UUID NOT NULL REFERENCES questions (id) ON DELETE RESTRICT,
            order_no     SMALLINT NOT NULL,
            served_at    TIMESTAMPTZ,
            PRIMARY KEY (match_id, question_id),
            UNIQUE (match_id, order_no)
        )
        """
    )

    # ---------- attempts (THE KEYSTONE) ----------
    # UNIQUE (match_id, question_id, user_id) = data-layer idempotency:
    # a reconnect or retry can never double-record an answer.
    op.execute(
        """
        CREATE TABLE attempts (
            id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            match_id        UUID NOT NULL REFERENCES matches (id)   ON DELETE CASCADE,
            question_id     UUID NOT NULL REFERENCES questions (id) ON DELETE RESTRICT,
            user_id         UUID NOT NULL REFERENCES users (id)     ON DELETE CASCADE,
            chosen_answer   TEXT,
            is_correct      BOOLEAN NOT NULL DEFAULT FALSE,
            response_ms     INTEGER,
            points_awarded  INTEGER NOT NULL DEFAULT 0,
            created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
            UNIQUE (match_id, question_id, user_id),
            CONSTRAINT response_ms_nonneg CHECK (response_ms IS NULL OR response_ms >= 0)
        )
        """
    )
    op.execute("CREATE INDEX idx_attempts_user     ON attempts (user_id)")
    op.execute("CREATE INDEX idx_attempts_question ON attempts (question_id)")
    op.execute("CREATE INDEX idx_attempts_match    ON attempts (match_id)")


def downgrade() -> None:
    # Drop in reverse dependency order. Dropping a table also drops its
    # triggers, so the function can be dropped after the tables.
    op.execute("DROP TABLE IF EXISTS attempts")
    op.execute("DROP TABLE IF EXISTS match_questions")
    op.execute("DROP TABLE IF EXISTS match_players")
    op.execute("DROP TABLE IF EXISTS matches")
    op.execute("DROP TABLE IF EXISTS questions")
    op.execute("DROP TABLE IF EXISTS users")
    op.execute("DROP FUNCTION IF EXISTS set_updated_at()")
    op.execute("DROP TYPE IF EXISTS connection_state")
    op.execute("DROP TYPE IF EXISTS match_status")
    op.execute("DROP TYPE IF EXISTS review_state")
    op.execute("DROP TYPE IF EXISTS difficulty_level")
    op.execute("DROP TYPE IF EXISTS gender_type")
    op.execute("DROP TYPE IF EXISTS user_role")
