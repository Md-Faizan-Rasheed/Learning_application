"""Records who did what to admin-privileged content — an independent trail
for exactly the situation "something changed, who/what did it," since app
state alone can't answer that after the fact.

Deliberately minimal: one INSERT via the *same* DB session as the mutating
request, so a log entry only survives if the request's own commit does
(get_db commits on success, rolls back on any exception) — no separate
transaction, so there's no way to end up with a logged action that never
actually happened, or a real mutation with no log entry.
"""

from __future__ import annotations

import json

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession


async def log_admin_action(
    db: AsyncSession,
    admin_user_id: str,
    action: str,
    *,
    target_type: str,
    target_id: str | None = None,
    detail: dict | None = None,
) -> None:
    """`action` is a short dotted verb like 'question.delete' or
    'stage.reorder' — free-form but keep it consistent so a future
    GET /admin/audit-log can filter on it usefully."""
    await db.execute(
        text(
            """
            INSERT INTO admin_audit_log (admin_user_id, action, target_type, target_id, detail)
            VALUES (:admin_user_id, :action, :target_type, :target_id, CAST(:detail AS jsonb))
            """
        ),
        {
            "admin_user_id": admin_user_id,
            "action": action,
            "target_type": target_type,
            "target_id": target_id,
            # default=str: callers often pass **data.model_dump() straight
            # through, which can carry UUID/datetime values json.dumps()
            # doesn't natively know how to encode — falling back to str()
            # for those keeps this a plain logging concern, not something
            # every call site has to pre-sanitize.
            "detail": json.dumps(detail, default=str) if detail is not None else None,
        },
    )
