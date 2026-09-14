"""word search: daily challenge scores

One shared, deterministically-seeded Word Search puzzle per calendar date
(computed client-side from the date alone, so every player gets the same
words/grid with no server round-trip needed to fetch it) — this table is
just where a finished attempt's score lands so friends can compare theirs
for the day, same shape as the existing friends leaderboard.

Revision ID: 0014_word_search_daily_scores
Revises: 0013_word_search_finds
Create Date: 2026-09-14
"""
from alembic import op

revision = "0014_word_search_daily_scores"
down_revision = "0013_word_search_finds"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        CREATE TABLE word_search_daily_scores (
            user_id         UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
            challenge_date  DATE NOT NULL,
            category        TEXT NOT NULL,
            score           INTEGER NOT NULL,
            seconds         INTEGER NOT NULL,
            created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
            PRIMARY KEY (user_id, challenge_date)
        )
        """
    )


def downgrade() -> None:
    op.execute("DROP TABLE word_search_daily_scores")
