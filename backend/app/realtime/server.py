"""Real-time layer (Socket.IO), mounted onto the same FastAPI process.

Task 1 scope: prove the transport. A client can connect, the server logs it,
and an `echo` event round-trips. Game logic (rooms, matches, questions) comes
in later Sprint 2 tasks and will live in this module.
"""

from __future__ import annotations

import asyncio
import random

import socketio

from ..config import settings
from ..db import SessionLocal
from ..game import repository as game_repo
from ..game.scoring import QUESTION_TIME_MS, score_answer
from ..moderation import repository as moderation_repo
from . import match_store
from .match_store import ROUNDS_PER_MATCH

# Pause between a round resolving and the next question appearing (ms).
INTER_ROUND_MS = 3500

# CORS for the socket handshake: same localhost-only policy as the REST app.
_cors = "*" if settings.env != "development" else [
    "http://localhost",
    "http://127.0.0.1",
]

# allow any localhost port in dev (Flutter web picks a random one)
sio = socketio.AsyncServer(
    async_mode="asgi",
    cors_allowed_origins="*" if settings.env == "development" else _cors,
)

# The ASGI wrapper is built in main.py, wrapping the FastAPI app so Socket.IO
# owns "/socket.io/*" and delegates everything else to FastAPI.


@sio.event
async def connect(sid: str, environ: dict, auth: dict | None = None) -> None:
    """Validate the JWT passed in the socket auth payload and remember who this
    connection belongs to. Guests without a token are allowed (anonymous play),
    but authenticated users get their real identity attached to their matches."""
    from ..auth.security import decode_access_token

    user_id = None
    role = "player"
    token = (auth or {}).get("token") if isinstance(auth, dict) else None
    if token:
        payload = decode_access_token(token)
        if payload and "sub" in payload:
            user_id = payload["sub"]
            role = payload.get("role", "player")

    # Stash on the socket session so later events (find_match) can read it.
    await sio.save_session(sid, {"user_id": user_id, "role": role})
    print(f"[ws] client connected: {sid} (user={user_id or 'anon'})")
    await sio.emit("server_hello", {"message": "connected", "sid": sid}, to=sid)


@sio.event
async def disconnect(sid: str, reason: str | None = None) -> None:
    match_id, player = await match_store.remove_player_by_sid(sid)
    print(f"[ws] client disconnected: {sid} (match={match_id})")
    if match_id:
        await _handle_pre_start_departure(match_id, player)
        await _broadcast_roster(match_id)


async def _handle_pre_start_departure(match_id: str, player: dict | None) -> None:
    """If someone leaves (explicitly or by disconnecting) a PARTY ROOM before
    it has started, actually free their seat and, if they were the host, hand
    the room off to the next-lowest seated player. Deliberately scoped to
    rooms only: quick-match's forming lobby intentionally keeps a disconnected
    human's seat reserved for a moment (reconnect grace) rather than freeing
    it — that existing behavior is unchanged here. A mid-match departure is
    also left alone either way, for the same reconnect reason."""
    if player is None:
        return
    meta = await match_store.get_meta(match_id)
    if not meta or meta.get("status") != "waiting" or meta.get("is_private") != "1":
        return
    await match_store.remove_seat(match_id, player["seat"])
    if int(meta.get("host_seat", -1)) == player["seat"]:
        remaining = await match_store.get_players(match_id)
        if remaining:
            new_host = min(p["seat"] for p in remaining)
            await match_store.set_meta_fields(match_id, host_seat=new_host)


@sio.event
async def echo(sid: str, data: dict) -> dict:
    """Round-trip check kept from Task 1 for debugging."""
    await sio.emit("echo_back", {"you_sent": data}, to=sid)
    return {"ok": True, "echoed": data}


async def _broadcast_roster(match_id: str) -> None:
    """Tell everyone in the room who is currently seated. Also carries party-room
    context (max_seats/room_code/is_host) — harmless no-ops for quick-match,
    where no seat matches host_seat and room_code is unset."""
    players = await match_store.get_players(match_id)
    meta = await match_store.get_meta(match_id)
    host_seat = int(meta["host_seat"]) if meta and meta.get("host_seat") not in (None, "") else -1
    await sio.emit(
        "roster",
        {
            "match_id": match_id,
            "max_seats": int(meta.get("max_seats", match_store.MAX_SEATS)) if meta else match_store.MAX_SEATS,
            "room_code": (meta or {}).get("room_code") or None,
            "players": [
                {"seat": p["seat"], "name": p["name"], "is_bot": p["is_bot"],
                 "connected": p["sid"] is not None, "is_host": p["seat"] == host_seat}
                for p in players
            ],
        },
        room=match_id,
    )


# Seconds a lobby waits for more humans before starting with bot backfill.
LOBBY_WAIT_SECONDS = 8
# Serialize lobby join/create so two joiners don't each open a lobby.
_lobby_lock = asyncio.Lock()


@sio.event
async def find_match(sid: str, data: dict) -> dict:
    """Real matchmaking: pool humans joining within a short window into the SAME
    match. The first joiner opens a lobby; others attach to it. When the lobby
    fills (4 seats) it starts immediately; otherwise a timer starts it with bots
    filling the empty seats.

    data: { name, difficulty? }
    """
    name = (data or {}).get("name") or "Player"
    difficulty = (data or {}).get("difficulty") or "easy"
    category = (data or {}).get("category") or "mixed"

    # Prefer the authenticated identity attached at connect-time.
    session = await sio.get_session(sid)
    auth_user_id = session.get("user_id") if session else None

    async with _lobby_lock:
        match_id = await match_store.find_open_match(difficulty, category)

        if match_id is not None and auth_user_id:
            # Don't pool a blocked pair together — only checkable for a real
            # account (a guest's identity is thrown away every join, so
            # there's nothing stable to have blocked). Falling back to None
            # here reuses the "no open lobby" branch below, opening a fresh
            # one instead of silently joining an incompatible pool.
            seated = await match_store.get_players(match_id)
            seated_human_ids = [p["user_id"] for p in seated if not p["is_bot"]]
            async with SessionLocal() as db:
                blocked = await moderation_repo.any_block_between(db, auth_user_id, seated_human_ids)
            if blocked:
                match_id = None

        if match_id is None:
            # No open lobby -> create one (durable DB match).
            async with SessionLocal() as db:
                match_id = await game_repo.create_db_match(db, difficulty)
                if auth_user_id:
                    db_user_id = auth_user_id  # real account
                    await game_repo.set_user_display_name(db, db_user_id, name)
                else:
                    db_user_id = await game_repo.create_db_user(db, name)  # anon guest
                await game_repo.add_match_player(db, match_id, db_user_id)
                await db.commit()
            await match_store.create_match(
                difficulty=difficulty, category=category, match_id=match_id
            )
            await match_store.set_open_match(difficulty, match_id, category)
            opened_new = True
        else:
            # Attach to the existing lobby.
            async with SessionLocal() as db:
                if auth_user_id:
                    db_user_id = auth_user_id
                    await game_repo.set_user_display_name(db, db_user_id, name)
                else:
                    db_user_id = await game_repo.create_db_user(db, name)
                await game_repo.add_match_player(db, match_id, db_user_id)
                await db.commit()
            opened_new = False

        player = await match_store.add_player(
            match_id, sid=sid, user_id=db_user_id, name=name, is_bot=False
        )
        await sio.enter_room(sid, match_id)
        humans = await match_store.count_humans(match_id)

    await _broadcast_roster(match_id)

    # If the lobby is now full of humans, start immediately.
    if player is not None and humans >= match_store.MAX_SEATS:
        await match_store.clear_open_match(difficulty, match_id, category)
        await _begin_match(match_id, difficulty)
    elif opened_new:
        asyncio.create_task(_lobby_timer(match_id, difficulty, category))

    return {
        "ok": True,
        "match_id": match_id,
        "seat": player["seat"] if player else None,
        "user_id": db_user_id,
    }


async def _lobby_timer(match_id: str, difficulty: str, category: str = "mixed") -> None:
    """After the wait window, close the lobby and start with bot backfill."""
    await asyncio.sleep(LOBBY_WAIT_SECONDS)
    meta = await match_store.get_meta(match_id)
    if not meta or meta.get("status") != "waiting":
        return  # already started (filled early) or gone
    await match_store.clear_open_match(difficulty, match_id, category)
    await _begin_match(match_id, difficulty)


# Serializes _begin_match per match_id. Without this, the "lobby filled up
# early" path (in find_match) and the LOBBY_WAIT_SECONDS timer can both pass
# the "still waiting" check before either has written status="active" —
# fill_with_bots alone spans several awaited Redis round-trips, plenty of
# room for both callers to interleave — and both go on to broadcast round 0,
# which looks to players like the first question getting skipped instantly.
_begin_locks: dict[str, asyncio.Lock] = {}


async def _begin_match(match_id: str, difficulty: str, *, fill_bots: bool = True) -> None:
    """Mark active and serve the first question. Quick-match backfills empty
    seats with bots (fill_bots=True, the default); party rooms start with
    however many real players are seated (fill_bots=False, see start_room)."""
    lock = _begin_locks.setdefault(match_id, asyncio.Lock())
    async with lock:
        # guard: only begin once
        meta = await match_store.get_meta(match_id)
        if not meta or meta.get("status") != "waiting":
            return
        if fill_bots:
            await match_store.fill_with_bots(match_id)
        await match_store.set_status(match_id, "active")
    _begin_locks.pop(match_id, None)
    await _broadcast_roster(match_id)
    await sio.emit("match_started", {"match_id": match_id}, room=match_id)
    await _start_and_broadcast_question(match_id, difficulty=difficulty, index=0)


_ROOM_SEAT_CHOICES = (4, 6, 8)


@sio.event
async def create_room(sid: str, data: dict) -> dict:
    """Host creates a private party room: no stranger matchmaking, no bot
    backfill, no lobby timer — it waits indefinitely (bounded only by Redis's
    usual match TTL) for the host to invite real friends by code and press Start.

    data: { name, difficulty?, category?, max_seats }
    """
    name = (data or {}).get("name") or "Player"
    difficulty = (data or {}).get("difficulty") or "easy"
    category = (data or {}).get("category") or "mixed"
    max_seats = (data or {}).get("max_seats")
    max_seats = max_seats if max_seats in _ROOM_SEAT_CHOICES else 4

    session = await sio.get_session(sid)
    auth_user_id = session.get("user_id") if session else None

    async with SessionLocal() as db:
        match_id = await game_repo.create_db_match(db, difficulty)
        if auth_user_id:
            db_user_id = auth_user_id
            await game_repo.set_user_display_name(db, db_user_id, name)
        else:
            db_user_id = await game_repo.create_db_user(db, name)
        await game_repo.add_match_player(db, match_id, db_user_id)
        await db.commit()

    await match_store.create_match(
        difficulty=difficulty, category=category, match_id=match_id, max_seats=max_seats
    )
    await match_store.set_meta_fields(match_id, is_private=1, host_seat=0)
    room_code = await match_store.generate_room_code(match_id)
    if room_code is None:
        return {"ok": False, "error": "could not generate a room code, try again"}

    player = await match_store.add_player(
        match_id, sid=sid, user_id=db_user_id, name=name, is_bot=False
    )
    await sio.enter_room(sid, match_id)
    await _broadcast_roster(match_id)

    return {
        "ok": True,
        "match_id": match_id,
        "seat": player["seat"] if player else 0,
        "user_id": db_user_id,
        "room_code": room_code,
        "max_seats": max_seats,
        "is_host": True,
    }


@sio.event
async def join_room(sid: str, data: dict) -> dict:
    """A friend joins a host's party room by its invite code.

    data: { name, room_code }
    """
    name = (data or {}).get("name") or "Player"
    room_code = ((data or {}).get("room_code") or "").strip().upper()
    if not room_code:
        return {"ok": False, "error": "room code required"}

    match_id = await match_store.match_id_for_room_code(room_code)
    if not match_id:
        return {"ok": False, "error": "room not found"}

    meta = await match_store.get_meta(match_id)
    if not meta or meta.get("status") != "waiting":
        return {"ok": False, "error": "room already started"}

    session = await sio.get_session(sid)
    auth_user_id = session.get("user_id") if session else None

    async with SessionLocal() as db:
        if auth_user_id:
            db_user_id = auth_user_id
            await game_repo.set_user_display_name(db, db_user_id, name)
        else:
            db_user_id = await game_repo.create_db_user(db, name)
        await game_repo.add_match_player(db, match_id, db_user_id)
        await db.commit()

    player = await match_store.add_player(
        match_id, sid=sid, user_id=db_user_id, name=name, is_bot=False
    )
    if player is None:
        return {"ok": False, "error": "room full"}

    await sio.enter_room(sid, match_id)
    await _broadcast_roster(match_id)

    return {
        "ok": True,
        "match_id": match_id,
        "seat": player["seat"],
        "user_id": db_user_id,
        "room_code": room_code,
        "is_host": False,
    }


@sio.event
async def start_room(sid: str, data: dict | None = None) -> dict:
    """The host starts their party room early (or once everyone's in) — no
    bot backfill, whoever's seated is who plays."""
    match_id = await match_store.match_id_for_sid(sid)
    if not match_id:
        return {"ok": False, "error": "not in a match"}

    meta = await match_store.get_meta(match_id)
    if not meta or meta.get("is_private") != "1":
        return {"ok": False, "error": "not a party room"}
    if meta.get("status") != "waiting":
        return {"ok": False, "error": "already started"}

    players = await match_store.get_players(match_id)
    seat = next((p["seat"] for p in players if p.get("sid") == sid), None)
    host_seat = int(meta.get("host_seat", -1))
    if seat is None or seat != host_seat:
        return {"ok": False, "error": "only the host can start"}

    humans = await match_store.count_humans(match_id)
    if humans < 2:
        return {"ok": False, "error": "need at least 2 players"}

    await _begin_match(match_id, meta.get("difficulty", "easy"), fill_bots=False)
    # Deliberately NOT releasing the room code here: join_room looks the code
    # up first and only then checks status, so an early release would turn a
    # clear "room already started" into a confusing "room not found" for
    # anyone who tries the code right after start. Let it expire with the
    # match's own TTL instead — same cleanup, better error message.
    return {"ok": True}


async def _start_and_broadcast_question(
    match_id: str, *, difficulty: str, index: int
) -> bool:
    """Pick a LIVE question and push it to every seat at once, with a shared
    server-controlled deadline. The correct answer is stored in Redis but is
    NEVER sent to clients."""
    import time as _t

    meta = await match_store.get_meta(match_id)
    category = meta.get("category", "mixed") if meta else "mixed"
    recent_questions = await match_store.get_recent_questions(match_id)
    async with SessionLocal() as db:
           q = await game_repo.pick_live_question(db, difficulty, category, recent_questions)
           await match_store.add_recent_question(match_id, str(q["id"]))
    if q is None:
        await sio.emit(
            "no_questions",
            {"message": "no live questions available for this difficulty"},
            room=match_id,
        )
        return False

    await match_store.start_round(
        match_id,
        question_id=str(q["id"]),
        correct_index=q["correct_index"],
        difficulty=q["difficulty"],
        prompt=q["prompt"],
        options=q["options"],
        time_ms=QUESTION_TIME_MS,
        round_no=index,
    )
    deadline_ms = int(_t.time() * 1000) + QUESTION_TIME_MS

    # Send all languages' text; each client renders its own. NO correct answer.
    await sio.emit(
        "question",
        {
            "match_id": match_id,
            "index": index,
            "question_id": str(q["id"]),
            "difficulty": q["difficulty"],
            "prompt": q["prompt"],       # {en, ur, ar}
            "options": q["options"],     # {en:[...], ur:[...], ar:[...]}
            "deadline_ms": deadline_ms,  # absolute epoch ms; clients count down to it
            "time_ms": QUESTION_TIME_MS,
        },
        room=match_id,
    )

    # Bots answer on their own after a short human-like delay; the deadline
    # watchdog resolves the round when everyone's in or time runs out.
    asyncio.create_task(_schedule_bot_answers(match_id, index))
    asyncio.create_task(_deadline_watchdog(match_id, index, QUESTION_TIME_MS))
    return True


async def _schedule_bot_answers(match_id: str, round_no: int) -> None:
    """Each bot answers after a random delay, with a fixed skill (accuracy)."""
    players = await match_store.get_players(match_id)
    rnd = await match_store.get_round(match_id)
    if not rnd:
        return
    n_options = len(rnd["options"]["en"])
    correct = rnd["correct_index"]
    for p in players:
        if not p["is_bot"]:
            continue
        delay = random.uniform(1.5, 6.0)
        asyncio.create_task(
            _bot_answer(match_id, round_no, p["seat"], correct, n_options, delay)
        )


async def _bot_answer(
    match_id: str, round_no: int, seat: int, correct: int, n_options: int, delay: float
) -> None:
    await asyncio.sleep(delay)
    # 60% accuracy bot; picks correct or a random wrong option.
    if random.random() < 0.6:
        chosen = correct
    else:
        wrong = [i for i in range(n_options) if i != correct]
        chosen = random.choice(wrong) if wrong else correct
    await _handle_answer(
        match_id, round_no, seat, chosen, int(delay * 1000), is_bot=True
    )


@sio.event
async def submit_answer(sid: str, data: dict) -> dict:
    """A human submits their answer for the current round. Server records it
    once (idempotent); resolution happens when all seats answer or time runs out.
    data: { chosen_index | null }
    """
    match_id = await match_store.match_id_for_sid(sid)
    if not match_id:
        return {"ok": False, "error": "not in a match"}
    rnd = await match_store.get_round(match_id)
    if not rnd:
        return {"ok": False, "error": "no active round"}

    # find this sid's seat
    players = await match_store.get_players(match_id)
    seat = next((p["seat"] for p in players if p.get("sid") == sid), None)
    if seat is None:
        return {"ok": False, "error": "no seat"}

    chosen = (data or {}).get("chosen_index")
    # Real elapsed time = now - when the question was shown (server-authoritative).
    import time as _t

    elapsed = max(0, int(_t.time() * 1000) - rnd["started_at_ms"])
    accepted = await _handle_answer(
        match_id, rnd["round_no"], seat, chosen, elapsed, is_bot=False
    )
    return {"ok": True, "accepted": accepted}


async def _handle_answer(
    match_id: str,
    round_no: int,
    seat: int,
    chosen_index: int | None,
    response_ms: int,
    *,
    is_bot: bool,
) -> bool:
    """Record one answer (idempotent) and resolve the round if everyone's in."""
    accepted = await match_store.record_answer(
        match_id,
        round_no,
        seat,
        {"chosen_index": chosen_index, "response_ms": response_ms, "is_bot": is_bot},
    )
    if not accepted:
        return False  # duplicate — ignore silently

    # Tell the room a seat has answered — never the choice itself, so
    # opponents can't infer anyone's pick before the round resolves. Purely
    # a live "who's still thinking" presence signal for the client.
    await sio.emit(
        "player_answered",
        {"match_id": match_id, "round_no": round_no, "seat": seat},
        room=match_id,
    )

    # If every seat has now answered, resolve immediately.
    answers = await match_store.get_answers(match_id, round_no)
    players = await match_store.get_players(match_id)
    if len(answers) >= len(players):
        await _resolve_round(match_id, round_no)
    return True


async def _deadline_watchdog(match_id: str, round_no: int, time_ms: int) -> None:
    """Force resolution when the deadline passes, even if some seats never answered."""
    await asyncio.sleep(time_ms / 1000)
    rnd = await match_store.get_round(match_id)
    # only resolve if this round is still the active one and not already resolved
    if rnd and rnd["round_no"] == round_no:
        await _resolve_round(match_id, round_no)


# guard so a round resolves exactly once (deadline vs all-answered race)
_resolving: set[str] = set()


async def _resolve_round(match_id: str, round_no: int) -> None:
    guard = f"{match_id}:{round_no}"
    if guard in _resolving:
        return
    _resolving.add(guard)
    try:
        rnd = await match_store.get_round(match_id)
        if not rnd or rnd["round_no"] != round_no:
            return
        correct = rnd["correct_index"]
        difficulty = rnd["difficulty"]
        question_id = rnd["question_id"]
        answers = await match_store.get_answers(match_id, round_no)
        players = {p["seat"]: p for p in await match_store.get_players(match_id)}

        results = []
        async with SessionLocal() as db:
            for seat, player in players.items():
                ans = answers.get(seat)
                chosen = ans["chosen_index"] if ans else None
                resp_ms = ans["response_ms"] if ans else None
                is_correct = chosen is not None and chosen == correct
                points = score_answer(
                    difficulty=difficulty, is_correct=is_correct, response_ms=resp_ms
                )
                total = await match_store.add_score(match_id, seat, points)

                # persist the attempt (real humans only; bots have synthetic ids
                # not present in users/matches, so we skip DB writes for them).
                if not player["is_bot"]:
                    try:
                        await game_repo.insert_attempt(
                            db,
                            match_id=match_id,
                            question_id=question_id,
                            user_id=player["user_id"],
                            chosen_answer=None,
                            is_correct=is_correct,
                            response_ms=resp_ms,
                            points_awarded=points,
                        )
                    except Exception as e:  # noqa: BLE001
                        print(f"[ws] attempt persist skipped (seat {seat}): {e}")

                results.append(
                    {
                        "seat": seat,
                        "name": player["name"],
                        "is_bot": player["is_bot"],
                        "chosen_index": chosen,
                        "is_correct": is_correct,
                        "points": points,
                        "total": total,
                        "response_ms": resp_ms,
                    }
                )
            await db.commit()

        results.sort(key=lambda r: r["total"], reverse=True)
        is_final = (round_no + 1) >= ROUNDS_PER_MATCH
        await sio.emit(
            "round_result",
            {
                "match_id": match_id,
                "round_no": round_no,
                "total_rounds": ROUNDS_PER_MATCH,
                "correct_index": correct,  # revealed AFTER answering
                "results": results,
                "is_final": is_final,
            },
            room=match_id,
        )
    finally:
        _resolving.discard(guard)

    # After the result is shown, either advance to the next question or finish.
    if is_final:
        await _end_match(match_id)
    else:
        asyncio.create_task(_advance_after_pause(match_id, round_no + 1))


async def _advance_after_pause(match_id: str, next_index: int) -> None:
    """Wait so players can read the result, then broadcast the next question."""
    await asyncio.sleep(INTER_ROUND_MS / 1000)
    meta = await match_store.get_meta(match_id)
    if not meta or meta.get("status") != "active":
        return  # match ended or was cleaned up
    difficulty = meta.get("difficulty", "easy")
    await _start_and_broadcast_question(match_id, difficulty=difficulty, index=next_index)


async def _end_match(match_id: str) -> None:
    """Finalize: mark done, broadcast final standings, and persist placements."""
    await match_store.set_status(match_id, "completed")
    scores = await match_store.get_scores(match_id)
    players = {p["seat"]: p for p in await match_store.get_players(match_id)}

    standings = [
        {
            "seat": seat,
            "name": players[seat]["name"],
            "is_bot": players[seat]["is_bot"],
            "user_id": players[seat]["user_id"],
            "total": scores.get(seat, 0),
        }
        for seat in players
    ]
    standings.sort(key=lambda s: s["total"], reverse=True)
    for placement, s in enumerate(standings, start=1):
        s["placement"] = placement

    # Persist final score + placement, and award XP + streak for real players.
    import datetime as _dt

    from ..progression import repository as prog_repo
    from ..quests import catalog as quest_catalog
    from ..quests import repository as quest_repo

    rewards: dict[int, dict] = {}
    async with SessionLocal() as db:
        for s in standings:
            player = players[s["seat"]]
            if player["is_bot"]:
                continue
            try:
                await game_repo.set_match_player_result(
                    db,
                    match_id=match_id,
                    user_id=player["user_id"],
                    final_score=s["total"],
                    placement=s["placement"],
                )
                # count this player's correct answers across the match
                correct = await game_repo.count_correct_answers(
                    db, match_id=match_id, user_id=player["user_id"]
                )
                reward = await prog_repo.apply_match_result(
                    db,
                    user_id=player["user_id"],
                    placement=s["placement"],
                    correct_answers=correct,
                    today=_dt.date.today(),
                )
                # advance daily quests: played a match, answered N correct, maybe won
                today = _dt.date.today()
                completed = []
                completed += await quest_repo.advance_quests(
                    db, player["user_id"], today,
                    event=quest_catalog.EVENT_MATCH_PLAYED, amount=1,
                )
                completed += await quest_repo.advance_quests(
                    db, player["user_id"], today,
                    event=quest_catalog.EVENT_CORRECT_ANSWER, amount=correct,
                )
                if s["placement"] == 1:
                    completed += await quest_repo.advance_quests(
                        db, player["user_id"], today,
                        event=quest_catalog.EVENT_MATCH_WON, amount=1,
                    )
                reward["quests_completed"] = [
                    {"description": c["description"], "reward_xp": c["reward_xp"]}
                    for c in completed
                ]
                rewards[s["seat"]] = reward
            except Exception as e:  # noqa: BLE001
                import traceback
                print(f"[ws] progression/quests error (seat {s['seat']}): {e}")
                traceback.print_exc()
        await db.commit()

    # attach each player's rewards to their standings row
    for s in standings:
        if s["seat"] in rewards:
            s["rewards"] = rewards[s["seat"]]

    await sio.emit(
        "match_over",
        {"match_id": match_id, "standings": standings},
        room=match_id,
    )


@sio.event
async def rejoin_match(sid: str, data: dict) -> dict:
    """Reconnect handshake. The client remembers its match_id + user_id across a
    drop and calls this; the server reattaches the seat and replays a snapshot
    of the current match state so the player resumes where they left off.

    data: { match_id, user_id }
    """
    import time as _t

    match_id = (data or {}).get("match_id")
    user_id = (data or {}).get("user_id")
    if not match_id or not user_id:
        return {"ok": False, "error": "match_id and user_id required"}

    meta = await match_store.get_meta(match_id)
    if not meta:
        return {"ok": False, "error": "match no longer exists"}

    player = await match_store.reseat_player(match_id, user_id, sid)
    if player is None:
        return {"ok": False, "error": "you are not in this match"}

    await sio.enter_room(sid, match_id)
    await _broadcast_roster(match_id)

    # Build a snapshot of what's happening right now, just for this client.
    status = meta.get("status")
    snapshot: dict = {"ok": True, "match_id": match_id, "seat": player["seat"], "status": status}

    if status == "completed":
        scores = await match_store.get_scores(match_id)
        snapshot["phase"] = "finished"
        snapshot["scores"] = scores
    else:
        rnd = await match_store.get_round(match_id)
        if rnd:
            remaining = max(0, rnd["started_at_ms"] + rnd["time_ms"] - int(_t.time() * 1000))
            already = await match_store.has_answered(match_id, rnd["round_no"], player["seat"])
            snapshot["phase"] = "question"
            snapshot["question"] = {
                "index": rnd["round_no"],
                "question_id": rnd["question_id"],
                "prompt": rnd["prompt"],
                "options": rnd["options"],
                "deadline_ms": rnd["started_at_ms"] + rnd["time_ms"],
                "time_ms": rnd["time_ms"],
                "remaining_ms": remaining,
                "already_answered": already,
            }
        else:
            snapshot["phase"] = "waiting"

    # Send the snapshot only to the reconnecting client.
    await sio.emit("resume_snapshot", snapshot, to=sid)
    return snapshot


@sio.event
async def leave_match(sid: str, data: dict | None = None) -> dict:
    match_id, player = await match_store.remove_player_by_sid(sid)
    if match_id:
        await sio.leave_room(sid, match_id)
        await _handle_pre_start_departure(match_id, player)
        await _broadcast_roster(match_id)
    return {"ok": True}
