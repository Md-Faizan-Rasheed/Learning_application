"""question i18n (Option B: inline translations)

Converts question content from single-language columns to language-keyed
JSON so one question renders in every player's language (en / ur / ar):

  prompt   TEXT               -> JSONB object  {"en": "...", "ur": "...", "ar": "..."}
  options  JSONB (array)      -> JSONB object  {"en": [...], "ur": [...], "ar": [...]}
  correct_answer TEXT         -> correct_index SMALLINT (language-independent
                                 index into the options arrays; every language
                                 lists options in the same order)

Existing English content is preserved (wrapped under the "en" key), so this
is backward compatible for any rows already present.

Revision ID: 0003_question_i18n
Revises: 0002_categories
Create Date: 2026-08-11
"""
from alembic import op

# revision identifiers, used by Alembic.
revision = "0003_question_i18n"
down_revision = "0002_categories"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # The old CHECK requires options to be an array; drop it before we
    # change options into an object.
    op.execute("ALTER TABLE questions DROP CONSTRAINT options_is_array")

    # options: array -> object, existing array preserved under "en"
    op.execute(
        "ALTER TABLE questions ALTER COLUMN options TYPE JSONB "
        "USING jsonb_build_object('en', options)"
    )
    # prompt: text -> object, existing text preserved under "en"
    op.execute(
        "ALTER TABLE questions ALTER COLUMN prompt TYPE JSONB "
        "USING jsonb_build_object('en', prompt)"
    )

    # correct_answer (text) -> correct_index (position in the en options array)
    op.execute("ALTER TABLE questions ADD COLUMN correct_index SMALLINT")
    op.execute(
        """
        UPDATE questions q
        SET correct_index = COALESCE((
            SELECT (ord - 1)::smallint
            FROM jsonb_array_elements_text(q.options->'en')
                 WITH ORDINALITY AS elem(val, ord)
            WHERE elem.val = q.correct_answer
            LIMIT 1
        ), 0)
        """
    )
    op.execute("ALTER TABLE questions ALTER COLUMN correct_index SET NOT NULL")
    op.execute("ALTER TABLE questions DROP COLUMN correct_answer")

    # new shape constraints
    op.execute(
        "ALTER TABLE questions ADD CONSTRAINT prompt_is_object "
        "CHECK (jsonb_typeof(prompt) = 'object')"
    )
    op.execute(
        "ALTER TABLE questions ADD CONSTRAINT options_is_object "
        "CHECK (jsonb_typeof(options) = 'object')"
    )
    op.execute(
        "ALTER TABLE questions ADD CONSTRAINT correct_index_nonneg "
        "CHECK (correct_index >= 0)"
    )


def downgrade() -> None:
    # restore correct_answer (text) from the en options array at correct_index
    op.execute("ALTER TABLE questions ADD COLUMN correct_answer TEXT")
    op.execute(
        "UPDATE questions q "
        "SET correct_answer = (q.options->'en'->>q.correct_index)"
    )
    op.execute("ALTER TABLE questions ALTER COLUMN correct_answer SET NOT NULL")

    # drop the new constraints and column
    op.execute("ALTER TABLE questions DROP CONSTRAINT correct_index_nonneg")
    op.execute("ALTER TABLE questions DROP CONSTRAINT options_is_object")
    op.execute("ALTER TABLE questions DROP CONSTRAINT prompt_is_object")
    op.execute("ALTER TABLE questions DROP COLUMN correct_index")

    # options: object -> array (take the en array back)
    op.execute(
        "ALTER TABLE questions ALTER COLUMN options TYPE JSONB "
        "USING (options->'en')"
    )
    # prompt: object -> text (take the en string back)
    op.execute(
        "ALTER TABLE questions ALTER COLUMN prompt TYPE TEXT "
        "USING (prompt->>'en')"
    )
    op.execute(
        "ALTER TABLE questions ADD CONSTRAINT options_is_array "
        "CHECK (jsonb_typeof(options) = 'array')"
    )
