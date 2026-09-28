from __future__ import annotations

import json

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

# Every stage starts with this much XP on offer, awarded once on claim.
# A near-static reference value — campaign_stage_progress.reward_xp is
# still per-row so a future per-stage override is a one-column UPDATE away.
DEFAULT_STAGE_REWARD_XP = 50


async def list_events(db: AsyncSession) -> list[dict]:
    """Every Seerah event, in the order they were seeded (chronological —
    see scripts/seerah_events_38.yaml) — feeds the admin question editor's
    event-tagging picker (content/routes.py:list_seerah_events). The table
    has no explicit ordinal column, so this relies on created_at."""
    rows = (
        await db.execute(
            text(
                "SELECT id, slug, name, year_hijri, summary FROM seerah_events "
                "ORDER BY created_at"
            )
        )
    ).mappings().all()
    return [dict(r) for r in rows]


async def create_event(
    db: AsyncSession, *, slug: str, name: dict, year_hijri: int | None, summary: dict | None
) -> dict:
    row = (
        await db.execute(
            text(
                """
                INSERT INTO seerah_events (slug, name, year_hijri, summary)
                VALUES (:slug, CAST(:name AS jsonb), :year_hijri, CAST(:summary AS jsonb))
                RETURNING id, slug, name, year_hijri, summary
                """
            ),
            {
                "slug": slug,
                "name": json.dumps(name),
                "year_hijri": year_hijri,
                "summary": json.dumps(summary) if summary is not None else None,
            },
        )
    ).mappings().one()
    return dict(row)


async def update_event(
    db: AsyncSession,
    event_id: str,
    *,
    slug: str | None,
    name: dict | None,
    year_hijri: int | None,
    summary: dict | None,
) -> dict | None:
    row = (
        await db.execute(
            text(
                """
                UPDATE seerah_events
                SET slug = COALESCE(:slug, slug),
                    name = COALESCE(CAST(:name AS jsonb), name),
                    year_hijri = COALESCE(:year_hijri, year_hijri),
                    summary = COALESCE(CAST(:summary AS jsonb), summary)
                WHERE id = :id
                RETURNING id, slug, name, year_hijri, summary
                """
            ),
            {
                "id": event_id,
                "slug": slug,
                "name": json.dumps(name) if name is not None else None,
                "year_hijri": year_hijri,
                "summary": json.dumps(summary) if summary is not None else None,
            },
        )
    ).mappings().first()
    return dict(row) if row else None


async def delete_event(db: AsyncSession, event_id: str) -> bool:
    """FK from questions.event_id (no cascade) blocks this with an
    IntegrityError if any question still points at the event — caller
    translates that into a 409. event_framework_tags rows for this event
    DO cascade-delete, so any stage link it carried goes with it."""
    result = await db.execute(text("DELETE FROM seerah_events WHERE id = :id"), {"id": event_id})
    return result.rowcount > 0


async def get_stage_id_by_slug(db: AsyncSession, slug: str) -> str | None:
    row = (
        await db.execute(
            text("SELECT id FROM campaign_stages WHERE slug = :s"), {"s": slug}
        )
    ).first()
    return str(row[0]) if row else None


async def get_stage_by_id(db: AsyncSession, stage_id: str) -> dict | None:
    row = (
        await db.execute(
            text(
                "SELECT id, slug, name, description, order_no FROM campaign_stages WHERE id = :id"
            ),
            {"id": stage_id},
        )
    ).mappings().first()
    return dict(row) if row else None


async def list_stages(db: AsyncSession) -> list[dict]:
    """Every campaign stage in canonical order — feeds the admin question
    list's stage-link picker (content/routes.py)."""
    rows = (
        await db.execute(
            text(
                "SELECT id, slug, name, description, order_no FROM campaign_stages "
                "ORDER BY order_no"
            )
        )
    ).mappings().all()
    return [dict(r) for r in rows]


async def create_stage(
    db: AsyncSession, *, slug: str, name: dict, description: dict | None
) -> dict:
    """New stages are appended after the current highest order_no — use
    reorder_stages afterward to move it, rather than guessing a slot here."""
    row = (
        await db.execute(
            text(
                """
                INSERT INTO campaign_stages (slug, name, description, order_no)
                VALUES (
                    :slug, CAST(:name AS jsonb), CAST(:description AS jsonb),
                    COALESCE((SELECT max(order_no) FROM campaign_stages), 0) + 1
                )
                RETURNING id, slug, name, description, order_no
                """
            ),
            {
                "slug": slug,
                "name": json.dumps(name),
                "description": json.dumps(description) if description is not None else None,
            },
        )
    ).mappings().one()
    return dict(row)


async def update_stage(
    db: AsyncSession,
    stage_id: str,
    *,
    slug: str | None,
    name: dict | None,
    description: dict | None,
) -> dict | None:
    """Renaming the slug also rewrites every event_framework_tags row that
    pointed at the old slug (movement_stage tags key on the slug string, not
    the stage id — see set_event_stage_tag) so existing question links to
    this stage survive the rename instead of silently going dangling."""
    current = await get_stage_by_id(db, stage_id)
    if current is None:
        return None
    row = (
        await db.execute(
            text(
                """
                UPDATE campaign_stages
                SET slug = COALESCE(:slug, slug),
                    name = COALESCE(CAST(:name AS jsonb), name),
                    description = COALESCE(CAST(:description AS jsonb), description)
                WHERE id = :id
                RETURNING id, slug, name, description, order_no
                """
            ),
            {
                "id": stage_id,
                "slug": slug,
                "name": json.dumps(name) if name is not None else None,
                "description": json.dumps(description) if description is not None else None,
            },
        )
    ).mappings().first()
    if row is not None and slug is not None and slug != current["slug"]:
        await db.execute(
            text(
                "UPDATE event_framework_tags SET tag_value = :new "
                "WHERE tag_value = :old AND framework = 'movement_stage'"
            ),
            {"new": slug, "old": current["slug"]},
        )
    return dict(row) if row else None


async def stage_linked_event_count(db: AsyncSession, slug: str) -> int:
    """How many events currently carry a movement_stage tag pointing at
    this stage's slug — used to block deleting a stage that's still in
    active use rather than leaving those tags pointing at nothing."""
    row = (
        await db.execute(
            text(
                "SELECT count(*) FROM event_framework_tags "
                "WHERE tag_value = :s AND framework = 'movement_stage'"
            ),
            {"s": slug},
        )
    ).first()
    return int(row[0]) if row else 0


async def delete_stage(db: AsyncSession, stage_id: str) -> bool:
    """FK from campaign_stage_progress/matches (no cascade) blocks this with
    an IntegrityError if any player has ever played this stage — caller
    translates that into a 409. Call stage_linked_event_count first to also
    block deleting a stage that's still linked to tagged questions."""
    result = await db.execute(text("DELETE FROM campaign_stages WHERE id = :id"), {"id": stage_id})
    return result.rowcount > 0


async def reorder_stages(db: AsyncSession, ordered_ids: list[str]) -> list[dict]:
    """Reassigns order_no 1..N to match ordered_ids exactly. Goes through a
    negative-offset pass first because order_no has a UNIQUE constraint —
    writing final positive values directly in one pass could collide with
    another row's still-current value mid-transaction."""
    for i, stage_id in enumerate(ordered_ids):
        await db.execute(
            text("UPDATE campaign_stages SET order_no = :o WHERE id = :id"),
            {"o": -(i + 1), "id": stage_id},
        )
    for i, stage_id in enumerate(ordered_ids):
        await db.execute(
            text("UPDATE campaign_stages SET order_no = :o WHERE id = :id"),
            {"o": i + 1, "id": stage_id},
        )
    return await list_stages(db)


async def set_event_stage_tag(db: AsyncSession, *, event_id: str, stage_slug: str | None) -> None:
    """Sets (or, when stage_slug is None, clears) the movement_stage tag on
    a Seerah event — the one thing that separates a merely event-tagged
    ('orphaned') question from one campaign mode can actually serve
    ('linked'). See content/repository.py's _ORPHANED_EVENT_CHECK. Affects
    every question tagged to this event at once, since the link lives on
    the event, not the individual question."""
    if stage_slug is None:
        await db.execute(
            text(
                "DELETE FROM event_framework_tags "
                "WHERE event_id = :e AND framework = 'movement_stage'"
            ),
            {"e": event_id},
        )
        return
    await db.execute(
        text(
            """
            INSERT INTO event_framework_tags (event_id, framework, tag_value)
            VALUES (:e, 'movement_stage', :s)
            ON CONFLICT (event_id, framework) DO UPDATE SET tag_value = :s
            """
        ),
        {"e": event_id, "s": stage_slug},
    )


async def get_stages_for_user(db: AsyncSession, user_id: str) -> list[dict]:
    rows = (
        await db.execute(
            text(
                """
                SELECT cs.id, cs.slug, cs.name, cs.description, cs.order_no,
                       COALESCE(csp.progress, 0) AS progress,
                       COALESCE(csp.target, 100) AS target,
                       csp.completed_at,
                       (
                           SELECT count(*)
                           FROM event_framework_tags eft
                           JOIN questions q
                                ON q.event_id = eft.event_id AND q.review_state = 'live'
                           WHERE eft.tag_value = cs.slug AND eft.framework = 'movement_stage'
                       ) AS question_count
                FROM campaign_stages cs
                LEFT JOIN campaign_stage_progress csp
                       ON csp.stage_id = cs.id AND csp.user_id = :u
                ORDER BY cs.order_no
                """
            ),
            {"u": user_id},
        )
    ).mappings().all()
    return [dict(r) for r in rows]


async def apply_stage_momentum(
    db: AsyncSession, *, user_id: str, stage_id: str, delta: int
) -> dict:
    """Adds `delta` momentum to this user's progress on this stage, creating
    the row on first play (with the default reward) and clamping at target.
    Marks completed_at the first time progress reaches target; never un-marks
    it on a later call (a completed stage stays completed)."""
    result = await db.execute(
        text(
            """
            INSERT INTO campaign_stage_progress
                (user_id, stage_id, progress, reward_xp, completed_at)
            VALUES (
                :u, :s, LEAST(100, :d), :xp,
                CASE WHEN LEAST(100, :d) >= 100 THEN now() ELSE NULL END
            )
            ON CONFLICT (user_id, stage_id) DO UPDATE
            SET progress = LEAST(campaign_stage_progress.target,
                                  campaign_stage_progress.progress + :d),
                completed_at = CASE
                    WHEN campaign_stage_progress.completed_at IS NOT NULL
                        THEN campaign_stage_progress.completed_at
                    WHEN campaign_stage_progress.progress + :d >= campaign_stage_progress.target
                        THEN now()
                    ELSE NULL
                END,
                updated_at = now()
            RETURNING progress, target, completed_at
            """
        ),
        {"u": user_id, "s": stage_id, "d": delta, "xp": DEFAULT_STAGE_REWARD_XP},
    )
    row = result.mappings().first()
    return dict(row)


async def complete_stage(db: AsyncSession, *, user_id: str, stage_id: str) -> dict:
    """Marks a stage fully complete after one played-to-the-end match,
    regardless of score — unlocking the next stage is "did you finish this
    stage's match", not a momentum score threshold accumulated over several
    replays. Idempotent: replaying an already-completed stage leaves its
    original completed_at untouched (a completed stage stays completed)."""
    result = await db.execute(
        text(
            """
            INSERT INTO campaign_stage_progress
                (user_id, stage_id, progress, reward_xp, completed_at)
            VALUES (:u, :s, 100, :xp, now())
            ON CONFLICT (user_id, stage_id) DO UPDATE
            SET progress = campaign_stage_progress.target,
                completed_at = COALESCE(campaign_stage_progress.completed_at, now()),
                updated_at = now()
            RETURNING progress, target, completed_at
            """
        ),
        {"u": user_id, "s": stage_id, "xp": DEFAULT_STAGE_REWARD_XP},
    )
    row = result.mappings().first()
    return dict(row)


async def claim_stage_reward(db: AsyncSession, *, user_id: str, stage_id: str) -> bool:
    """Mirrors quests/repository.py's advance_quests claim pattern exactly —
    direct total_xp update guarded by a reward_claimed flag, no streak
    involvement (stage completion is a one-off bonus, not a daily habit)."""
    row = (
        await db.execute(
            text(
                """
                SELECT reward_xp, reward_claimed, completed_at
                FROM campaign_stage_progress WHERE user_id = :u AND stage_id = :s
                """
            ),
            {"u": user_id, "s": stage_id},
        )
    ).mappings().first()
    if not row or not row["completed_at"] or row["reward_claimed"]:
        return False

    await db.execute(
        text("UPDATE users SET total_xp = total_xp + :xp WHERE id = :u"),
        {"xp": row["reward_xp"], "u": user_id},
    )
    await db.execute(
        text(
            """
            UPDATE campaign_stage_progress SET reward_claimed = TRUE
            WHERE user_id = :u AND stage_id = :s
            """
        ),
        {"u": user_id, "s": stage_id},
    )
    return True
