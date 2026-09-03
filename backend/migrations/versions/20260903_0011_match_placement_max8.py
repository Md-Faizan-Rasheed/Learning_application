"""widen match placement range for party rooms

Party rooms allow up to 8 seats (vs. quick-match's 4), so a player can now
finish in placement 5-8. Widens the existing CHECK constraint accordingly;
no data migration needed since no existing row can violate a widened range.

Revision ID: 0011_match_placement_max8
Revises: 0010_password_reset
Create Date: 2026-09-03
"""
from alembic import op

revision = "0011_match_placement_max8"
down_revision = "0010_password_reset"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TABLE match_players DROP CONSTRAINT placement_range")
    op.execute(
        "ALTER TABLE match_players ADD CONSTRAINT placement_range "
        "CHECK (placement IS NULL OR placement BETWEEN 1 AND 8)"
    )


def downgrade() -> None:
    op.execute("ALTER TABLE match_players DROP CONSTRAINT placement_range")
    op.execute(
        "ALTER TABLE match_players ADD CONSTRAINT placement_range "
        "CHECK (placement IS NULL OR placement BETWEEN 1 AND 4)"
    )
