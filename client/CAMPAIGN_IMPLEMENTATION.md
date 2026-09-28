# Campaign Map — Implementation Spec (v2, audit-corrected)

This supersedes the earlier generic prompt. Everything below is written
against the actual codebase (audit dated 2026-09-24), not assumptions.
Where the earlier plan was wrong, that's called out explicitly so
whoever implements this understands *why* the shape changed.

## 0. What the audit changed about the plan

- **Questions are picked one at a time, live, per round** — via
  `pick_live_question()` — not batched into `match_questions` (that
  table exists in the schema but is never written to anywhere in
  `backend/app/`). Campaign mode extends the live-pick function; it
  does not populate a question set up front.
- **No FSRS. No Glicko/ELO. No IRT logic runs anywhere** — `skill_mu`/
  `skill_sigma`/`irt_difficulty` are schema columns with zero code
  touching them. Campaign mode must not be built to depend on any of
  these — it only uses what's actually live: the `difficulty` enum and
  tag/category filters.
- **`matches.status` is never updated after insert.** Match lifecycle
  lives in Redis (`match_store`) plus writes to `match_players` at the
  end. `matches.campaign_stage_id` is a write-once tag set at creation
  for durable record-keeping — runtime logic reads the campaign stage
  from the Redis meta hash, not by re-querying Postgres mid-match.
- **XP claiming should copy the `daily_quests` pattern exactly**
  (`quests/repository.py`'s `advance_quests`: a direct
  `UPDATE users SET total_xp = total_xp + :xp`, guarded by a
  `reward_claimed` flag) — **not** `apply_match_result`/
  `apply_activity_result`, which also touch `streak_days`. Stage
  completion is a quest-shaped bonus, not a streak event.
- **Matches are created via Socket.IO, not REST**, with plain dict
  payloads (no Pydantic in `realtime/server.py`). The campaign stage
  is a new optional key in the existing `find_match`/`create_room`
  payloads, not a new REST endpoint.
- **No feature-flag system exists anywhere in this codebase.** There's
  no mechanism to reuse for staged rollout — see §5.

---

## 1. Migration

Use `20260924_0015_add_campaign_map.py` (already corrected: `down_revision
= "0014_word_search_daily_scores"`, confirmed UUID PKs, confirmed
`set_updated_at()` trigger, two new indexes added to match the existing
`idx_questions_pick` convention). Apply it, then run a seed script that
upserts `seerah_events_38.yaml` into `seerah_events` +
`event_framework_tags`, resolving `category_slug: seerah` against the
existing `categories` row (confirmed present, slug `'seerah'`).

---

## 2. Backend

### 2.1 `app/game/repository.py` — extend `pick_live_question`

Add one optional parameter. Existing callers (which never pass it)
get byte-identical query behavior.

```python
async def pick_live_question(
    db: AsyncSession,
    difficulty: str | None = None,
    category_slug: str | None = None,
    recent_questions: list[str] | None = None,
    stage_slug: str | None = None,          # NEW — optional, default None
) -> dict | None:
    joins = "JOIN categories c ON c.id = q.category_id"
    filters = ["q.review_state = 'live'", "c.is_active = TRUE"]
    params: dict = {}

    if difficulty:
        filters.append("q.difficulty = :difficulty")
        params["difficulty"] = difficulty

    if category_slug and category_slug != "mixed":
        filters.append("c.slug = :category_slug")
        params["category_slug"] = category_slug

    if stage_slug:
        joins += """
            JOIN event_framework_tags eft
              ON eft.event_id = q.event_id
             AND eft.framework = 'movement_stage'
        """
        filters.append("eft.tag_value = :stage_slug")
        params["stage_slug"] = stage_slug

    if recent_questions:
        filters.append("q.id NOT IN (SELECT unnest(:recent))")
        params["recent"] = recent_questions

    query = f"""
        SELECT q.*
        FROM questions q
        {joins}
        WHERE {' AND '.join(filters)}
        ORDER BY random()
        LIMIT 1
    """
    result = await db.execute(text(query), params)
    row = result.mappings().first()
    return dict(row) if row else None
```

Remove the leftover debug `print()` statements while you're in this
function (noted in the audit as pre-existing, not something to leave
behind now that the function is being touched anyway — but that's a
cleanup, not a requirement; skip it if you'd rather keep this diff
minimal).

### 2.2 `app/realtime/match_store.py` — new campaign methods

Follow the existing hash + TTL pattern used for `scores`
(`HINCRBY`, `match:{match_id}:scores`). New key:
`match:{match_id}:campaign` (same `_TTL_SECONDS`).

```python
async def get_campaign_stage(match_id: str) -> str | None:
    """Reads campaign_stage_id back out of the meta hash set at creation."""
    return await redis.hget(f"match:{match_id}:meta", "campaign_stage_id")

async def increment_campaign_momentum(match_id: str, delta: int, streak_broken: bool) -> dict:
    key = f"match:{match_id}:campaign"
    await redis.hincrby(key, "momentum", delta)
    if streak_broken:
        await redis.hset(key, "streak", 0)
    else:
        await redis.hincrby(key, "streak", 1)
    await redis.expire(key, _TTL_SECONDS)
    momentum = int(await redis.hget(key, "momentum") or 0)
    streak = int(await redis.hget(key, "streak") or 0)
    return {"momentum": min(momentum, 100), "streak": streak}
```

At match creation, add `campaign_stage_id` as one more field in the
existing `match:{match_id}:meta` hash write (wherever that currently
happens alongside `status`/`difficulty`/`category`) — set once, read
by both the question-pick call site and `_end_match`.

### 2.3 `app/realtime/server.py` — three additive hook points

**a) `find_match` / `create_room`** — accept one new optional key in
the existing plain-dict payload:

```python
# find_match(sid, data):  data = {name, difficulty?, category?, stage_slug?}
stage_slug = data.get("stage_slug")
campaign_stage_id = None
if stage_slug:
    campaign_stage_id = await campaign_repo.get_stage_id_by_slug(db, stage_slug)

match_id = await game_repo.create_db_match(
    db, difficulty, campaign_stage_id=campaign_stage_id  # NEW optional kwarg
)
# ...existing add_match_player call, unchanged...
await match_store.set_meta(match_id, ..., campaign_stage_id=campaign_stage_id)
```

`create_db_match` (`game/repository.py:203-217`) gets one new optional
kwarg threaded into its existing `INSERT INTO matches (...)` — same
minimal-diff shape as the migration's column addition.

For matchmaking, also add a campaign-scoped lobby key alongside the
existing `open:{category}:{difficulty}` one — e.g.
`open:campaign:{stage_slug}:{difficulty}` — so quick-match pairs
campaign players with other campaign players on the *same stage*,
rather than pooling into the general Seerah lobby.

**b) Round resolution (wherever `_resolve_round` determines
correctness, before it emits `round_result`)** — additive block, only
runs when a campaign stage is set:

```python
campaign_stage_id = await match_store.get_campaign_stage(match_id)
if campaign_stage_id:
    was_correct = ...  # already computed here for round_result
    result = await match_store.increment_campaign_momentum(
        match_id, delta=(4 if was_correct else 0), streak_broken=not was_correct
    )
    await sio.emit("stage_momentum", {
        "match_id": match_id, **result
    }, room=match_id)
```

`stage_momentum` is a **new, separate event** — `round_result`'s own
payload and every other existing emit in this function is untouched.

**c) `_end_match` (`server.py:650-738`)** — additive block after the
existing quest/XP calls, before `db.commit()`:

```python
campaign_stage_id = await match_store.get_campaign_stage(match_id)
if campaign_stage_id:
    momentum = await match_store.get_campaign_momentum(match_id)  # final value
    for user_id in non_bot_user_ids:
        stage_result = await campaign_repo.apply_stage_momentum(
            db, user_id=user_id, stage_id=campaign_stage_id, delta=momentum
        )
        await sio.emit("campaign_progress", {
            "stage_id": campaign_stage_id,
            "progress": stage_result["progress"],
            "completed": stage_result["completed_at"] is not None,
        }, room=sid_for(user_id))
```

`campaign_progress` is a **new event, emitted separately from
`match_over`** — deliberately not folded into `match_over`'s payload,
so that event's shape stays literally unchanged for every match,
campaign or not.

### 2.4 `app/campaign/repository.py` (new file)

```python
async def get_stage_id_by_slug(db: AsyncSession, slug: str) -> str | None:
    result = await db.execute(
        text("SELECT id FROM campaign_stages WHERE slug = :s"), {"s": slug}
    )
    row = result.first()
    return str(row[0]) if row else None


async def get_stages_for_user(db: AsyncSession, user_id: str) -> list[dict]:
    result = await db.execute(text("""
        SELECT cs.id, cs.slug, cs.name, cs.order_no, cs.description,
               COALESCE(csp.progress, 0) AS progress,
               COALESCE(csp.target, 100) AS target,
               csp.completed_at
        FROM campaign_stages cs
        LEFT JOIN campaign_stage_progress csp
               ON csp.stage_id = cs.id AND csp.user_id = :u
        ORDER BY cs.order_no
    """), {"u": user_id})
    return [dict(r) for r in result.mappings().all()]
    # Derive "locked"/"current"/"completed" in Python from completed_at +
    # order_no, same as the earlier design — no extra column needed.


async def apply_stage_momentum(
    db: AsyncSession, *, user_id: str, stage_id: str, delta: int
) -> dict:
    result = await db.execute(text("""
        INSERT INTO campaign_stage_progress (user_id, stage_id, progress)
        VALUES (:u, :s, :d)
        ON CONFLICT (user_id, stage_id) DO UPDATE
        SET progress = LEAST(campaign_stage_progress.target,
                              campaign_stage_progress.progress + :d),
            completed_at = CASE
                WHEN campaign_stage_progress.progress + :d >= campaign_stage_progress.target
                THEN now() ELSE campaign_stage_progress.completed_at
            END,
            updated_at = now()
        RETURNING progress, completed_at
    """), {"u": user_id, "s": stage_id, "d": delta})
    row = result.mappings().first()
    return dict(row)


async def claim_stage_reward(db: AsyncSession, *, user_id: str, stage_id: str) -> bool:
    """Mirrors quests/repository.py's advance_quests claim pattern exactly —
    direct XP update, reward_claimed guard, no streak involvement."""
    row = await db.execute(text("""
        SELECT reward_xp, reward_claimed, completed_at
        FROM campaign_stage_progress WHERE user_id = :u AND stage_id = :s
    """), {"u": user_id, "s": stage_id})
    progress = row.mappings().first()
    if not progress or not progress["completed_at"] or progress["reward_claimed"]:
        return False

    await db.execute(
        text("UPDATE users SET total_xp = total_xp + :xp WHERE id = :u"),
        {"xp": progress["reward_xp"], "u": user_id},
    )
    await db.execute(text("""
        UPDATE campaign_stage_progress SET reward_claimed = TRUE
        WHERE user_id = :u AND stage_id = :s
    """), {"u": user_id, "s": stage_id})
    await db.commit()
    return True
```

### 2.5 `app/campaign/schemas.py` + `app/campaign/routes.py` (new)

Matches the existing per-domain `routes.py` pattern (Pydantic +
`response_model=`, unlike the Pydantic-free realtime handlers):

```python
# schemas.py
class CampaignStageOut(BaseModel):
    id: UUID
    slug: str
    name: dict          # {en, ur, ar}
    order_no: int
    state: str           # "locked" | "current" | "completed"
    progress: int
    target: int

class ClaimResult(BaseModel):
    claimed: bool

# routes.py
@router.get("/stages", response_model=list[CampaignStageOut])
async def list_stages(user=Depends(get_current_user), db=Depends(get_db)):
    rows = await campaign_repo.get_stages_for_user(db, user.id)
    return [derive_state(r) for r in rows]  # locked/current/completed logic here

@router.post("/stage/{stage_id}/claim", response_model=ClaimResult)
async def claim_stage(stage_id: UUID, user=Depends(get_current_user), db=Depends(get_db)):
    claimed = await campaign_repo.claim_stage_reward(db, user_id=str(user.id), stage_id=str(stage_id))
    return ClaimResult(claimed=claimed)
```

---

## 3. Flutter

Matches confirmed conventions: `setState`, no state-management
package, imperative `Navigator.push(MaterialPageRoute(...))`, a
`MatchSocket` wrapper class, ARB + `AppLocalizations.of(context)!`,
`AppPalette` tokens from `app_theme.dart`.

### 3.1 `CampaignMapScreen` (new file)
`StatefulWidget` fetching `GET /campaign/stages`; renders the winding
path (see the earlier mockup for layout reference, but pull colors
from `AppPalette`/`Theme.of(context).colorScheme`, not hardcoded hex).

### 3.2 `HomeScreen` bottom nav — smallest possible diff
Add one `NavigationDestination` to the existing hardcoded list in
`main.dart`, and one `case` to `_onNavTap`'s switch, pushing
`CampaignMapScreen` via `Navigator.of(context).push(MaterialPageRoute(...))`
— same pattern every other destination already uses. Don't introduce
an `IndexedStack` or restructure `selectedIndex` handling to do this.

### 3.3 `MultiplayerScreen` — additive constructor param, not a fork
```dart
class MultiplayerScreen extends StatefulWidget {
  final String? campaignStageId;   // NEW, default null
  const MultiplayerScreen({super.key, this.campaignStageId, ...});
}
```
In `_connect()`, alongside the seven existing `_socket.on(...)` calls:
```dart
if (widget.campaignStageId != null) {
  _socket.on('stage_momentum', _handleStageMomentum);
  _socket.on('campaign_progress', _handleCampaignProgress);
}
```
When creating the match, thread `stage_slug` into the existing
`find_match`/`create_room` emit payload only if `campaignStageId !=
null`. Render the momentum bar conditionally on the same flag. Grep
every current call site of `MultiplayerScreen` and confirm none of
them change — they'll all simply not pass `campaignStageId`, and the
widget's output must be identical to today for all of them.

### 3.4 `StageClearedScreen` (new file)
Pushed from `_handleCampaignProgress` when its payload's `completed`
is `true`. "Continue" button calls `POST /campaign/stage/{id}/claim`.

### 3.5 Localization
Stage/event names come pre-localized from the DB (`campaign_stages.name`
/ `seerah_events.name` are already `{en, ur, ar}` JSONB — no ARB entries
needed for those). Static UI chrome (nav label, screen titles, "Stage
Cleared", "Continue") goes through the existing
`app_en.arb`/`app_ar.arb`/`app_ur.arb` + `AppLocalizations.of(context)!`
pipeline, same as everywhere else. Only add a manual `Directionality`
override (matching the ~12-file existing precedent) if the winding
path's left/right zig-zag needs to visually mirror under RTL locales —
don't add one if the automatic locale-driven direction already reads
correctly.

---

## 4. Testing

Follow the existing conventions exactly: real local dev Postgres (no
separate test DB), unique generated emails, explicit cleanup, no
mocks, `pytest-asyncio` with `asyncio_mode = auto`.

New backend tests:
- `pick_live_question` with `stage_slug` set vs. unset — confirm the
  unset case returns identical rows/behavior to before this change.
- `claim_stage_reward` idempotency — second claim call returns `False`
  and doesn't double-award XP.
- A full ordinary (non-campaign) match created and played through
  `find_match` → `submit_answer` → `_end_match`, asserting the exact
  same sequence and payload shape of Socket.IO emits as before this
  feature existed — this is the regression test that actually proves
  constraint #1 (no behavior change for non-campaign matches) held.

Flutter: a widget test confirming `MultiplayerScreen` built with no
`campaignStageId` renders identically to a snapshot taken before this
change, if you can capture one; otherwise, at minimum confirm no new
widgets/momentum bar appear when the param is omitted.

---

## 5. Rollout

Confirmed: no feature-flag or remote-config system exists anywhere in
this codebase (backend or client) — nothing to reuse. Two real
options, not a default to assume:
1. Ship the nav item as soon as it's ready — matches how every other
   feature in this app appears to have shipped (direct to the nav).
2. Build a single new hardcoded boolean constant to hide the nav item
   until you're ready — this is new infrastructure, however small, not
   reuse of an existing pattern, so treat it as a deliberate addition
   worth a one-line justification in the PR rather than something to
   add silently.