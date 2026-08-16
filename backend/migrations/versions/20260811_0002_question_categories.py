"""question categories

Promotes `category` from a free-text column on `questions` to a
first-class, admin-managed `categories` table (seerah, arabic, and any
category an admin creates later). Questions now reference a category by
FK, and a match records which category is being played (players choose).

Revision ID: 0002_categories
Revises: 0001_stage1
Create Date: 2026-08-11
"""
from alembic import op

# revision identifiers, used by Alembic.
revision = "0002_categories"
down_revision = "0001_stage1"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ---------- categories (admin-managed) ----------
    op.execute(
        """
        CREATE TABLE categories (
            id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            slug          TEXT        NOT NULL UNIQUE,   -- 'seerah', 'arabic', ...
            display_name  TEXT        NOT NULL,
            description   TEXT,
            is_active     BOOLEAN     NOT NULL DEFAULT TRUE,   -- hide without deleting
            created_by    UUID        REFERENCES users (id) ON DELETE SET NULL,
            created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
            updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
        )
        """
    )
    op.execute(
        "CREATE TRIGGER trg_categories_updated BEFORE UPDATE ON categories "
        "FOR EACH ROW EXECUTE FUNCTION set_updated_at()"
    )

    # starter categories
    op.execute(
        "INSERT INTO categories (slug, display_name) VALUES "
        "('seerah', 'Seerah'), ('arabic', 'Arabic')"
    )

    # ---------- questions: text category -> FK ----------
    op.execute(
        "ALTER TABLE questions ADD COLUMN category_id UUID "
        "REFERENCES categories (id) ON DELETE RESTRICT"
    )
    # backfill any existing rows whose free-text category matches a slug
    op.execute(
        "UPDATE questions q SET category_id = c.id "
        "FROM categories c WHERE q.category = c.slug"
    )
    # replace the old hot-path index (it referenced the text column)
    op.execute("DROP INDEX IF EXISTS idx_questions_pick")
    op.execute("ALTER TABLE questions DROP COLUMN category")
    op.execute("ALTER TABLE questions ALTER COLUMN category_id SET NOT NULL")
    op.execute(
        "CREATE INDEX idx_questions_pick ON questions (difficulty, category_id) "
        "WHERE review_state = 'live'"
    )
    op.execute("CREATE INDEX idx_questions_category ON questions (category_id)")

    # ---------- matches: which category is being played ----------
    # Nullable = the "All / Mixed" mode (no single category filter).
    op.execute(
        "ALTER TABLE matches ADD COLUMN category_id UUID "
        "REFERENCES categories (id) ON DELETE RESTRICT"
    )
    op.execute("CREATE INDEX idx_matches_category ON matches (category_id)")


def downgrade() -> None:
    # matches: drop the category column
    op.execute("DROP INDEX IF EXISTS idx_matches_category")
    op.execute("ALTER TABLE matches DROP COLUMN category_id")

    # questions: restore the free-text category column
    op.execute("DROP INDEX IF EXISTS idx_questions_category")
    op.execute("DROP INDEX IF EXISTS idx_questions_pick")
    op.execute("ALTER TABLE questions ADD COLUMN category TEXT")
    op.execute(
        "UPDATE questions q SET category = c.slug "
        "FROM categories c WHERE q.category_id = c.id"
    )
    op.execute("ALTER TABLE questions ALTER COLUMN category SET NOT NULL")
    op.execute("ALTER TABLE questions DROP COLUMN category_id")
    op.execute(
        "CREATE INDEX idx_questions_pick ON questions (difficulty, category) "
        "WHERE review_state = 'live'"
    )

    # drop categories (its trigger is dropped with the table)
    op.execute("DROP TABLE IF EXISTS categories")
