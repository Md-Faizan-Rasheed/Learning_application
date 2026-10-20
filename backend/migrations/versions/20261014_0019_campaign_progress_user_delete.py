"""Cascade campaign progress when its owning user is deleted.

Revision ID: 0019_campaign_progress_user_delete
Revises: 0018_audit_log_user_delete
Create Date: 2026-10-14
"""
from alembic import op

revision = "0019_campaign_progress_user_delete"
down_revision = "0018_audit_log_user_delete"
branch_labels = None
depends_on = None


def upgrade():
    op.execute(
        "ALTER TABLE campaign_stage_progress "
        "DROP CONSTRAINT campaign_stage_progress_user_id_fkey;"
    )
    op.execute(
        "ALTER TABLE campaign_stage_progress "
        "ADD CONSTRAINT campaign_stage_progress_user_id_fkey "
        "FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;"
    )


def downgrade():
    op.execute(
        "ALTER TABLE campaign_stage_progress "
        "DROP CONSTRAINT campaign_stage_progress_user_id_fkey;"
    )
    op.execute(
        "ALTER TABLE campaign_stage_progress "
        "ADD CONSTRAINT campaign_stage_progress_user_id_fkey "
        "FOREIGN KEY (user_id) REFERENCES users(id);"
    )
