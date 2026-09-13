"""word search: per-user found-words record

Tracks which words a user has ever found in the Word Search minigame, per
category (prophets / namesOfAllah / hijriMonths / ...). This is what makes
a "found every X in a category" achievement possible — until now the
backend only knew a puzzle's word *count*, not which specific words were
found, so it could never tell "found all 25 Prophets" apart from "found 25
Prophets across many partial replays".

Revision ID: 0013_word_search_finds
Revises: 0012_moderation
Create Date: 2026-09-14
"""
from alembic import op

revision = "0013_word_search_finds"
down_revision = "0012_moderation"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        CREATE TABLE word_search_finds (
            user_id         UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
            category        TEXT NOT NULL,
            word            TEXT NOT NULL,
            first_found_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
            PRIMARY KEY (user_id, category, word)
        )
        """
    )


def downgrade() -> None:
    op.execute("DROP TABLE word_search_finds")
