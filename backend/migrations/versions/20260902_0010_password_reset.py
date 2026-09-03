"""password reset

Adds a single-use reset token + expiry directly on users (same lean-columns
style already used for friend_code) rather than a separate table, since a
user only ever has at most one active reset request at a time.

Revision ID: 0010_password_reset
Revises: 0009_social_features
Create Date: 2026-09-02
"""
from alembic import op

revision = "0010_password_reset"
down_revision = "0009_social_features"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TABLE users ADD COLUMN password_reset_token TEXT UNIQUE")
    op.execute("ALTER TABLE users ADD COLUMN password_reset_expires_at TIMESTAMPTZ")


def downgrade() -> None:
    op.execute("ALTER TABLE users DROP COLUMN IF EXISTS password_reset_token")
    op.execute("ALTER TABLE users DROP COLUMN IF EXISTS password_reset_expires_at")
