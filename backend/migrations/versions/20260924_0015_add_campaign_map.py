"""add campaign map (seerah events, framework tags, stages, progress)

Revision ID: 0015_add_campaign_map
Revises: 0014_word_search_daily_scores
Create Date: 2026-09-24

Confirmed against the actual schema (codebase audit, 2026-09-24):
- PKs are UUID DEFAULT gen_random_uuid() everywhere, including composite
  junction-table PKs — matches the pattern used here.
- The existing updated_at trigger function is set_updated_at(), defined
  once in 20260811_0001_stage1_foundations.py and reused by 5 other
  tables — reused as-is below, no rename needed.
- Enum type names in this schema are singular snake_case
  (review_state, user_role, difficulty_level) — campaign_framework
  follows that convention.
- categories already has a 'seerah' row (seeded in
  20260811_0002_question_categories.py) — seerah_events.category_id
  should be backfilled to that row's id in the seed step, not here.
"""
from alembic import op

revision = "0015_add_campaign_map"
down_revision = "0014_word_search_daily_scores"
branch_labels = None
depends_on = None


def upgrade():
    op.execute("""
        CREATE TYPE campaign_framework AS ENUM (
            'movement_stage', 'geographic', 'age_based', 'trial_based',
            'role_based', 'revelation_based', 'two_period'
        );
    """)

    # Canonical, ordered list of movement-stage campaign stages.
    # A near-static reference table — 9 rows, seeded below, edited rarely.
    op.execute("""
        CREATE TABLE campaign_stages (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            slug TEXT UNIQUE NOT NULL,
            name JSONB NOT NULL,          -- {en, ur, ar} — matches questions.prompt convention
            description JSONB,            -- {en, ur, ar}, nullable
            order_no INT UNIQUE NOT NULL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT now()
        );
    """)

    # Specific historical happenings — one row per "thing that happened",
    # independent of which framework(s) it gets studied under.
    op.execute("""
        CREATE TABLE seerah_events (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            category_id UUID REFERENCES categories(id),
            name JSONB NOT NULL,          -- {en, ur, ar}
            year_hijri INT,
            summary JSONB,                -- {en, ur, ar}, nullable
            created_at TIMESTAMPTZ NOT NULL DEFAULT now()
        );
    """)

    # One row per (event, framework): which lens-specific bucket that event
    # falls into. A single event can carry a row per framework simultaneously.
    op.execute("""
        CREATE TABLE event_framework_tags (
            event_id UUID NOT NULL REFERENCES seerah_events(id) ON DELETE CASCADE,
            framework campaign_framework NOT NULL,
            tag_value TEXT NOT NULL,      -- 'hijrah_relocation', 'madinah', 'fear_and_danger'...
            PRIMARY KEY (event_id, framework)
        );
    """)

    # Every campaign question-pick joins this on (framework, tag_value) —
    # same reasoning as the existing idx_questions_pick partial index.
    op.execute("""
        CREATE INDEX idx_event_framework_tags_lookup
        ON event_framework_tags (framework, tag_value);
    """)

    # Let existing questions optionally point at the event they're testing.
    # Nullable: non-Seerah questions (fiqh, general knowledge, etc.) are untouched.
    op.execute("""
        ALTER TABLE questions ADD COLUMN event_id UUID REFERENCES seerah_events(id);
    """)
    op.execute("""
        CREATE INDEX idx_questions_event_id ON questions (event_id);
    """)

    # Let a match remember which campaign stage it was played for.
    # Nullable: ordinary matches (not part of the campaign) are unaffected.
    op.execute("""
        ALTER TABLE matches ADD COLUMN campaign_stage_id UUID REFERENCES campaign_stages(id);
    """)

    # Per-player progress through each stage — same shape as daily_quests
    # (progress/target/reward_xp/reward_claimed) so it reuses the same
    # claim/reward pattern your progression code already knows how to handle.
    op.execute("""
        CREATE TABLE campaign_stage_progress (
            user_id UUID NOT NULL REFERENCES users(id),
            stage_id UUID NOT NULL REFERENCES campaign_stages(id),
            progress INT NOT NULL DEFAULT 0,
            target INT NOT NULL DEFAULT 100,
            reward_xp INT NOT NULL DEFAULT 0,
            reward_claimed BOOLEAN NOT NULL DEFAULT false,
            completed_at TIMESTAMPTZ,
            updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
            PRIMARY KEY (user_id, stage_id)
        );
    """)

    # Reuse whichever trigger function your other 5 updated_at columns use.
    op.execute("""
        CREATE TRIGGER set_campaign_progress_updated_at
        BEFORE UPDATE ON campaign_stage_progress
        FOR EACH ROW EXECUTE FUNCTION set_updated_at();
    """)

    # Seed the canonical 9 movement-stage rows. Translate ur/ar before shipping —
    # left null here as a placeholder, not invented translations.
    op.execute("""
        INSERT INTO campaign_stages (slug, name, order_no) VALUES
        ('tazkiyah',            '{"en": "Tazkiyah", "ur": null, "ar": null}', 1),
        ('secret_dawah',        '{"en": "Secret Dawah", "ur": null, "ar": null}', 2),
        ('open_dawah',          '{"en": "Open Dawah", "ur": null, "ar": null}', 3),
        ('search_for_a_base',   '{"en": "Search for a Base", "ur": null, "ar": null}', 4),
        ('hijrah_relocation',   '{"en": "Hijrah", "ur": null, "ar": null}', 5),
        ('state_building',      '{"en": "State-Building", "ur": null, "ar": null}', 6),
        ('defense_consolidation','{"en": "Defense & Consolidation", "ur": null, "ar": null}', 7),
        ('expansion_dominance', '{"en": "Expansion & Dominance", "ur": null, "ar": null}', 8),
        ('completion',          '{"en": "Completion", "ur": null, "ar": null}', 9);
    """)


def downgrade():
    op.execute("DROP TRIGGER IF EXISTS set_campaign_progress_updated_at ON campaign_stage_progress;")
    op.execute("DROP TABLE IF EXISTS campaign_stage_progress;")
    op.execute("ALTER TABLE matches DROP COLUMN IF EXISTS campaign_stage_id;")
    op.execute("DROP INDEX IF EXISTS idx_questions_event_id;")
    op.execute("ALTER TABLE questions DROP COLUMN IF EXISTS event_id;")
    op.execute("DROP INDEX IF EXISTS idx_event_framework_tags_lookup;")
    op.execute("DROP TABLE IF EXISTS event_framework_tags;")
    op.execute("DROP TABLE IF EXISTS seerah_events;")
    op.execute("DROP TABLE IF EXISTS campaign_stages;")
    op.execute("DROP TYPE IF EXISTS campaign_framework;")