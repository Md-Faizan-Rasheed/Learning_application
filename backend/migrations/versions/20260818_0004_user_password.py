"""auth: add password_hash to users

Adds a nullable password_hash column so email/password accounts can log in.
NULL means a guest / passwordless account (e.g. the throwaway users created
by matchmaking today), so this is backward compatible with existing rows.

Revision ID: 0004_user_password
Revises: 0003_question_i18n
Create Date: 2026-08-18
"""
from alembic import op

revision = "0004_user_password"
down_revision = "0003_question_i18n"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TABLE users ADD COLUMN password_hash TEXT")


def downgrade() -> None:
    op.execute("ALTER TABLE users DROP COLUMN password_hash")