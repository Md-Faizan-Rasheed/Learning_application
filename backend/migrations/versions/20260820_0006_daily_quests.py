"""quests: daily_quests table

Per-user, per-day quest progress. Rows are created lazily the first time a user
requests their quests for a given date, so no scheduled job is needed.

Revision ID: 0006_daily_quests
Revises: 0005_user_total_xp
Create Date: 2026-08-20
"""
from alembic import op

revision = "0006_daily_quests"
down_revision = "0005_user_total_xp"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        CREATE TABLE daily_quests (
            id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            quest_date   date NOT NULL,
            quest_key    text NOT NULL,
            description  text NOT NULL,
            target       integer NOT NULL,
            progress     integer NOT NULL DEFAULT 0,
            completed    boolean NOT NULL DEFAULT FALSE,
            reward_xp    integer NOT NULL,
            reward_claimed boolean NOT NULL DEFAULT FALSE,
            created_at   timestamptz NOT NULL DEFAULT now(),
            UNIQUE (user_id, quest_date, quest_key)
        )
        """
    )
    op.execute(
        "CREATE INDEX ix_daily_quests_user_date ON daily_quests (user_id, quest_date)"
    )


def downgrade() -> None:
    op.execute("DROP TABLE daily_quests")