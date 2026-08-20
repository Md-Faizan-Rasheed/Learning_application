# Islamic Learning Game — Architecture (current state)

_Last updated: end of Stage 2 (progression). This reflects what is actually built and tested, not the original plan._

## 1. What exists today

A working, server-authoritative, trilingual (English / Urdu / Arabic), real-time multiplayer learning game with real accounts and a progression loop.

A player can:
- Register, log in, or continue as a guest (session persists across launches).
- Play **solo practice** — one live question at a time, server-graded.
- Play **4-player multiplayer** — real human-vs-human matchmaking, synchronized rounds, live scoring, reconnect after a drop.
- Earn **XP and a daily streak**, and see their profile and recent match history.

An admin can add scholar-reviewed questions (draft → reviewed → live) via API or a bulk JSON import script.

## 2. Stack

- **Client:** Flutter (web target during development; the same codebase targets mobile).
- **Backend:** FastAPI (Python), a modular monolith — one process, feature modules inside it.
- **Real-time:** python-socketio, wrapping the FastAPI app in the same process (Socket.IO owns `/socket.io/*`, delegates everything else to FastAPI).
- **Databases:** PostgreSQL (durable records) + Redis (live match state). Alembic for migrations.
- **Run command:** `uvicorn app.main:asgi_app --reload` (note: `asgi_app`, the Socket.IO wrapper — not `app`).

## 3. Core principle: the server is the single authority

The client never receives correct answers, timing, or scores before it has committed an answer. Specifically:
- A served question contains prompt + options only — never the correct index.
- Correctness, speed scoring, and placement are computed server-side.
- The correct answer is revealed only after the round resolves.
- Answers are idempotent — a double-submit or retry cannot overwrite or double-score.

This is enforced everywhere questions are served: both practice (`game/`) and multiplayer (`realtime/`).

## 4. Backend module map (`backend/app/`)

Every feature module follows the same shape: `schemas.py` (data in/out), `repository.py` (SQL), `routes.py` (HTTP). Pure logic that deserves isolation gets its own file (e.g. `scoring.py`, `rules.py`, `security.py`).

- **`config.py`** — env settings (DB, Redis, admin key, JWT secret/TTL).
- **`db.py` / `redis_client.py`** — async engine/session; async Redis client.
- **`common/deps.py`** — shared dependencies: `get_db`, `get_current_user` (JWT), `require_admin_user` (admin JWT or legacy key), plus the optional-user variant.
- **`health/`** — `/health` (checks db + redis).
- **`auth/`** — register / login / guest / me. `security.py` = argon2 hashing + JWT create/decode. Real accounts, guest accounts (passwordless), role-based admin gating.
- **`content/`** — admin-only category + question management, with the trilingual validation and the draft→reviewed→live review workflow. Only `live` questions in `active` categories are ever served.
- **`game/`** — solo practice: serve a live question (answer withheld) + judge an answer (server-scored, attempt persisted). `scoring.py` holds the pure point rules. `repository.py` also holds the durable-match/user helpers used by multiplayer.
- **`realtime/`** — the multiplayer engine (see §6). `server.py` = socket events + match orchestration; `match_store.py` = Redis live state.
- **`progression/`** — XP + daily streak. `rules.py` = pure XP/streak math; `repository.py` = applies rewards + reads profile; `routes.py` = `GET /me/profile`.

## 5. Data model (essentials)

PostgreSQL owns durable records:
- **`users`** — identity, role, gender (for matchmaking), `password_hash` (nullable → guest), `streak_days`, `streak_freezes`, `last_played_on`, `total_xp`.
- **`categories`** — first-class, admin-managed, `is_active`.
- **`questions`** — trilingual `prompt` and `options` stored as JSONB `{en,ur,ar}`; the correct answer is a language-independent `correct_index`; `review_state` (draft/reviewed/live); `category_id`; `difficulty`.
- **`matches`** / **`match_players`** — durable match records; `match_players` carries `final_score` and `placement`.
- **`attempts`** — one row per answered question, with `UNIQUE(match_id, question_id, user_id)` as the idempotency guard.

Redis owns ephemeral live-match state, keyed by `match_id` so any instance could rebuild a match:
- `match:{id}:meta` — status, difficulty.
- `match:{id}:players` — seat → player.
- `match:{id}:round` — the active question (incl. correct_index, server-side only).
- `match:{id}:round:{n}:answers` — collected answers for a round.
- `match:{id}:scores` — running scores.
- `open:{difficulty}` — the currently-forming matchmaking lobby.
- `sid:{sid}` — reverse lookup for disconnects.

### Migrations (Alembic)
`0001` foundations · `0002` question categories · `0003` question i18n (Option B JSONB) · `0004` user password_hash · `0005` user total_xp.

## 6. The multiplayer engine (`realtime/`)

Lifecycle of a match:
1. **Connect** — client opens a socket, optionally with a JWT. Authenticated users get their real identity attached to the session; tokenless connections play anonymously.
2. **Matchmaking** — `find_match` pools humans by difficulty into a shared lobby. The first joiner opens the lobby (`open:{difficulty}`); others attach within an 8-second window. Starts immediately at 4 humans, or on the timer with bots filling only the leftover seats. An `asyncio.Lock` serializes lobby creation; compare-and-delete closes it safely.
3. **Synchronized question** — the server broadcasts one question to all seats at once with a shared absolute `deadline_ms` (so all clients count down to the same wall-clock instant). The correct answer stays in Redis.
4. **Simultaneous resolution** — all seats submit; bots auto-answer (60% accuracy, human-like delay); a deadline watchdog forces resolution if someone never answers. The server judges each answer, scores by speed, persists attempts, and broadcasts the round result + leaderboard. A resolve-once guard handles the deadline-vs-all-answered race.
5. **Multi-round flow** — a match runs `ROUNDS_PER_MATCH` (5) questions, pausing ~3.5s between rounds, then ends.
6. **Match end** — final standings broadcast; `final_score` + `placement` persisted; **XP + streak awarded** per real player via `progression`.
7. **Reconnect** — a dropped client rejoins with its `match_id` + `user_id` and receives a `resume_snapshot` (live question with remaining time, or between-rounds state); its seat is restored.

## 7. Progression (Stage 2)

On match end, each real player earns XP = finish bonus (10) + 5 × correct answers + placement bonus (30/15/5/0), and their daily streak advances (first play → 1; consecutive day → +1; same day → unchanged; a gap → reset to 1). All the numbers live in `progression/rules.py`. `GET /me/profile` exposes XP, streak, and recent matches; the client shows a reward celebration on the match-over screen and a profile screen.

## 8. Content loading

`scripts/import_content.py` bulk-loads a JSON file of categories + trilingual questions, reusing the same Pydantic validators as the admin API. Questions load as `draft` (respecting the review workflow) unless `--live` is passed; `--dry-run` validates without writing. This is the path for loading real Seerah / Arabic question banks.

## 9. Known gaps / backlog

- **Reconnect grace / bot-substitution after timeout** — a dropped player keeps their seat for the match TTL; no automatic bot takeover yet.
- **Matchmaking filters** — pools by difficulty only. Gender and category filters, and TrueSkill skill-matching, are designed but not built.
- **JWT secret length** — dev secret is short (harmless locally; set a 32+ char secret before any deployment).
- **Silent reward errors** — the match-end reward code catches and logs exceptions rather than surfacing them (this hid a missing-function bug during development); worth making louder.
- **FSRS spaced repetition, daily quests, onboarding polish, friends/private rooms, monetization** — future stages.

## 10. Operational notes (dev environment)

- Keep the project **out of OneDrive** (on a plain local path like `C:\dev\...`) — cloud sync locks files and breaks Flutter/Alembic writes.
- The venv is not portable — recreate it after moving the project.
- Alembic needs `DATABASE_URL` in the shell (or a `.env` autoload in `migrations/env.py`).
- After applying a multi-file update, grep for the new function/field names before restarting — partial file updates were a recurring source of "silent" bugs.
- Delete the relevant `__pycache__` after replacing a module if a change doesn't seem to take effect.