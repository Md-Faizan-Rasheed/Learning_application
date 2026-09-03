"""report / block mechanism

Adds player-to-player reporting (queued for admin review) and blocking
(kept out of future quick-match pairings) — mirrors the lean
table-per-relationship style already used for friend_requests/challenges.

Revision ID: 0012_moderation
Revises: 0011_match_placement_max8
Create Date: 2026-09-03
"""
from alembic import op

revision = "0012_moderation"
down_revision = "0011_match_placement_max8"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        CREATE TABLE reports (
            id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            reporter_id       UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
            reported_user_id  UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
            reason            TEXT NOT NULL
                              CHECK (reason IN ('inappropriate_name','cheating','harassment','spam','other')),
            details           TEXT,
            match_id          UUID REFERENCES matches (id) ON DELETE SET NULL,
            status            TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','reviewed','dismissed')),
            created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
            reviewed_at       TIMESTAMPTZ,
            CONSTRAINT no_self_report CHECK (reporter_id <> reported_user_id)
        )
        """
    )
    op.execute("CREATE INDEX idx_reports_status ON reports (status, created_at)")

    op.execute(
        """
        CREATE TABLE blocks (
            blocker_id  UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
            blocked_id  UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
            created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
            PRIMARY KEY (blocker_id, blocked_id),
            CONSTRAINT no_self_block CHECK (blocker_id <> blocked_id)
        )
        """
    )
    op.execute("CREATE INDEX idx_blocks_blocked ON blocks (blocked_id)")


def downgrade() -> None:
    op.execute("DROP TABLE IF EXISTS blocks")
    op.execute("DROP TABLE IF EXISTS reports")
