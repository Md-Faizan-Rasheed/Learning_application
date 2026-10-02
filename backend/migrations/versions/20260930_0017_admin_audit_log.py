"""admin_audit_log: independent record of admin-panel mutations

Every destructive/mutating admin action (question/stage/event CRUD, review
promotions, moderation report decisions) previously left no trace of who
did it or when — app state alone can't answer "did an admin action cause
this, or was it something else" after the fact. This table is written from
the same DB session as the mutating request (see app/common/audit_log.py),
so an entry only survives if the request's own commit does.

Revision ID: 0017_admin_audit_log
Revises: 0016_seerah_events_slug
Create Date: 2026-09-30
"""
from alembic import op

revision = "0017_admin_audit_log"
down_revision = "0016_seerah_events_slug"
branch_labels = None
depends_on = None


def upgrade():
    op.execute("""
        CREATE TABLE admin_audit_log (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            admin_user_id UUID NOT NULL REFERENCES users(id),
            action TEXT NOT NULL,            -- 'question.delete', 'stage.reorder', ...
            target_type TEXT NOT NULL,
            target_id TEXT,
            detail JSONB,
            created_at TIMESTAMPTZ NOT NULL DEFAULT now()
        );
    """)
    # Every read of this table (a future GET /admin/audit-log, or an ad-hoc
    # query when something looks wrong) filters or sorts by these.
    op.execute("CREATE INDEX idx_admin_audit_log_created_at ON admin_audit_log (created_at DESC);")
    op.execute("CREATE INDEX idx_admin_audit_log_admin_user_id ON admin_audit_log (admin_user_id);")
    op.execute("CREATE INDEX idx_admin_audit_log_target ON admin_audit_log (target_type, target_id);")


def downgrade():
    op.execute("DROP TABLE IF EXISTS admin_audit_log;")
