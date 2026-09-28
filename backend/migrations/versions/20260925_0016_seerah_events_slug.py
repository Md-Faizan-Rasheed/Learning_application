"""seerah_events: add unique slug column

0015_add_campaign_map created seerah_events without a stable business key,
but the seed script (backend/scripts/seed_campaign_content.py) needs to
upsert seerah_events_38.yaml idempotently on re-run — ON CONFLICT needs a
unique column to target. seerah_events is empty at this point (seeded only
by that script, which hasn't run yet), so NOT NULL is safe to add directly
with no backfill.

Revision ID: 0016_seerah_events_slug
Revises: 0015_add_campaign_map
Create Date: 2026-09-25
"""
from alembic import op

revision = "0016_seerah_events_slug"
down_revision = "0015_add_campaign_map"
branch_labels = None
depends_on = None


def upgrade():
    op.execute("""
        ALTER TABLE seerah_events ADD COLUMN slug TEXT UNIQUE NOT NULL;
    """)


def downgrade():
    op.execute("ALTER TABLE seerah_events DROP COLUMN IF EXISTS slug;")
