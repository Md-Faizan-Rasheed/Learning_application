"""admin_audit_log: let a log entry survive its actor's account being deleted

0017 gave admin_user_id a plain FK (implicit ON DELETE NO ACTION), which
means deleting an admin account now fails with a ForeignKeyViolationError
the moment they have any audit history — exactly backwards for a table
whose whole point is to be a record independent of live app state. An
audit entry should outlive the account that produced it; ON DELETE SET
NULL keeps the action/target/detail/timestamp and just drops the now-dead
reference, so admin_user_id has to become nullable to allow that.

Revision ID: 0018_audit_log_user_delete
Revises: 0017_admin_audit_log
Create Date: 2026-09-30
"""
from alembic import op

revision = "0018_audit_log_user_delete"
down_revision = "0017_admin_audit_log"
branch_labels = None
depends_on = None


def upgrade():
    op.execute("ALTER TABLE admin_audit_log ALTER COLUMN admin_user_id DROP NOT NULL;")
    op.execute("ALTER TABLE admin_audit_log DROP CONSTRAINT admin_audit_log_admin_user_id_fkey;")
    op.execute("""
        ALTER TABLE admin_audit_log
        ADD CONSTRAINT admin_audit_log_admin_user_id_fkey
        FOREIGN KEY (admin_user_id) REFERENCES users(id) ON DELETE SET NULL;
    """)


def downgrade():
    op.execute("ALTER TABLE admin_audit_log DROP CONSTRAINT admin_audit_log_admin_user_id_fkey;")
    op.execute("""
        ALTER TABLE admin_audit_log
        ADD CONSTRAINT admin_audit_log_admin_user_id_fkey
        FOREIGN KEY (admin_user_id) REFERENCES users(id);
    """)
    op.execute("ALTER TABLE admin_audit_log ALTER COLUMN admin_user_id SET NOT NULL;")
