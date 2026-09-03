"""user question contributions

Adds an index supporting the new user-generated-content feature: players can
submit questions (stored via the existing questions.created_by column, which
existed since stage 1 but was never populated) that go through the existing
review_state workflow. Once an admin promotes a submission to 'live', the
contributor is rewarded. This migration only adds the index needed for the
"how many of this user's questions are live" count query — no new columns,
since review_state/is_private/created_by already exist.

Revision ID: 0008_user_contributions
Revises: 0007_teacher_quizzes
Create Date: 2026-09-01
"""
from alembic import op

revision = "0008_user_contributions"
down_revision = "0007_teacher_quizzes"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        "CREATE INDEX idx_questions_created_by ON questions (created_by, review_state)"
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS idx_questions_created_by")
