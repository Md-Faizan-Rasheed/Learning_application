"""social features: friend codes, friend requests, async challenges

Adds a unique friend_code to users (DB-level default so every existing
insert path — register, guest, and the ad-hoc match-created accounts in
game/repository.py — gets one automatically with no application code
changes), a friend_requests table (accepted rows double as the friendship
record, no separate friendships table), and a challenges table for async
score challenges between friends.

Revision ID: 0009_social_features
Revises: 0008_user_contributions
Create Date: 2026-09-01
"""
from alembic import op

revision = "0009_social_features"
down_revision = "0008_user_contributions"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        ALTER TABLE users
        ADD COLUMN friend_code TEXT UNIQUE
            DEFAULT upper(substr(md5(random()::text || clock_timestamp()::text), 1, 8))
        """
    )
    op.execute(
        "UPDATE users SET friend_code = upper(substr(md5(random()::text || clock_timestamp()::text), 1, 8)) "
        "WHERE friend_code IS NULL"
    )
    op.execute(
        """
        CREATE TABLE friend_requests (
            id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            from_user_id  UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
            to_user_id    UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
            status        TEXT NOT NULL DEFAULT 'pending'
                          CHECK (status IN ('pending', 'accepted', 'declined')),
            created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
            responded_at  TIMESTAMPTZ,
            CONSTRAINT no_self_friend_request CHECK (from_user_id <> to_user_id)
        )
        """
    )
    op.execute("CREATE INDEX idx_friend_requests_to   ON friend_requests (to_user_id, status)")
    op.execute("CREATE INDEX idx_friend_requests_from ON friend_requests (from_user_id, status)")

    op.execute(
        """
        CREATE TABLE challenges (
            id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            challenger_id    UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
            opponent_id      UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
            category         TEXT NOT NULL DEFAULT 'mixed',
            question_count   INTEGER NOT NULL DEFAULT 8,
            challenger_score INTEGER,
            opponent_score   INTEGER,
            status           TEXT NOT NULL DEFAULT 'pending'
                             CHECK (status IN ('pending', 'completed')),
            winner_id        UUID REFERENCES users (id) ON DELETE SET NULL,
            created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
            completed_at     TIMESTAMPTZ,
            CONSTRAINT no_self_challenge CHECK (challenger_id <> opponent_id)
        )
        """
    )
    op.execute("CREATE INDEX idx_challenges_challenger ON challenges (challenger_id, status)")
    op.execute("CREATE INDEX idx_challenges_opponent   ON challenges (opponent_id, status)")


def downgrade() -> None:
    op.execute("DROP TABLE IF EXISTS challenges")
    op.execute("DROP TABLE IF EXISTS friend_requests")
    op.execute("ALTER TABLE users DROP COLUMN IF EXISTS friend_code")
