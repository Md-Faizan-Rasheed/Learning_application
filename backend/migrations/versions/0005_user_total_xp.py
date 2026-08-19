"""progression: add total_xp to users

Adds a running XP total. streak_days / streak_freezes / last_played_on already
exist from the Stage 1 foundations migration, so only XP storage is new.
DEFAULT 0 keeps this backward compatible with existing rows.

Revision ID: 0005_user_total_xp
Revises: 0004_user_password
Create Date: 2026-08-19
"""
from alembic import op

revision = "0005_user_total_xp"
down_revision = "0004_user_password"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TABLE users ADD COLUMN total_xp INTEGER NOT NULL DEFAULT 0")


def downgrade() -> None:
    op.execute("ALTER TABLE users DROP COLUMN total_xp")