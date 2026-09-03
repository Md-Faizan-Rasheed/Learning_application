from __future__ import annotations

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession


async def user_exists(db: AsyncSession, user_id: str) -> bool:
    row = (await db.execute(text("SELECT 1 FROM users WHERE id = :u"), {"u": user_id})).first()
    return row is not None


async def create_report(
    db: AsyncSession,
    *,
    reporter_id: str,
    reported_user_id: str,
    reason: str,
    details: str | None,
    match_id: str | None,
) -> dict:
    row = (
        await db.execute(
            text(
                """
                INSERT INTO reports (reporter_id, reported_user_id, reason, details, match_id)
                VALUES (:reporter, :reported, :reason, :details, :match_id)
                RETURNING id, reported_user_id, reason, status
                """
            ),
            {
                "reporter": reporter_id,
                "reported": reported_user_id,
                "reason": reason,
                "details": details,
                "match_id": match_id,
            },
        )
    ).mappings().one()
    return dict(row)


async def list_reports(db: AsyncSession, status: str) -> list[dict]:
    rows = (
        await db.execute(
            text(
                """
                SELECT r.id, r.reporter_id, ru.display_name AS reporter_name,
                       r.reported_user_id, tu.display_name AS reported_name,
                       r.reason, r.details, r.match_id, r.status,
                       to_char(r.created_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS created_at
                FROM reports r
                JOIN users ru ON ru.id = r.reporter_id
                JOIN users tu ON tu.id = r.reported_user_id
                WHERE r.status = :status
                ORDER BY r.created_at DESC
                """
            ),
            {"status": status},
        )
    ).mappings().all()
    return [dict(r) for r in rows]


async def set_report_status(db: AsyncSession, report_id: str, status: str) -> dict | None:
    row = (
        await db.execute(
            text(
                """
                UPDATE reports
                SET status = :status, reviewed_at = now()
                WHERE id = :id
                RETURNING id, reporter_id, reported_user_id, reason, status
                """
            ),
            {"status": status, "id": report_id},
        )
    ).mappings().first()
    return dict(row) if row else None


async def block_user(db: AsyncSession, blocker_id: str, blocked_id: str) -> None:
    await db.execute(
        text(
            """
            INSERT INTO blocks (blocker_id, blocked_id)
            VALUES (:blocker, :blocked)
            ON CONFLICT (blocker_id, blocked_id) DO NOTHING
            """
        ),
        {"blocker": blocker_id, "blocked": blocked_id},
    )


async def unblock_user(db: AsyncSession, blocker_id: str, blocked_id: str) -> None:
    await db.execute(
        text("DELETE FROM blocks WHERE blocker_id = :blocker AND blocked_id = :blocked"),
        {"blocker": blocker_id, "blocked": blocked_id},
    )


async def list_blocked(db: AsyncSession, blocker_id: str) -> list[dict]:
    rows = (
        await db.execute(
            text(
                """
                SELECT u.id AS user_id, u.display_name
                FROM blocks b
                JOIN users u ON u.id = b.blocked_id
                WHERE b.blocker_id = :blocker
                ORDER BY b.created_at DESC
                """
            ),
            {"blocker": blocker_id},
        )
    ).mappings().all()
    return [dict(r) for r in rows]


async def any_block_between(db: AsyncSession, user_id: str, other_user_ids: list[str]) -> bool:
    """True if [user_id] has blocked, or is blocked by, ANY of [other_user_ids]
    (either direction) — used by quick-match to avoid pairing blocked players
    without either of them ever seeing why."""
    if not other_user_ids:
        return False
    row = (
        await db.execute(
            text(
                """
                SELECT 1 FROM blocks
                WHERE (blocker_id = :u AND blocked_id = ANY(:others))
                   OR (blocked_id = :u AND blocker_id = ANY(:others))
                LIMIT 1
                """
            ),
            {"u": user_id, "others": other_user_ids},
        )
    ).first()
    return row is not None
