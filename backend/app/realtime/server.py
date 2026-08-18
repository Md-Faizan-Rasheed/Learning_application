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
    # TODO(auth-epic): validate a real token from `auth` here.
    print(f"[ws] client connected: {sid}")
    await sio.emit("server_hello", {"message": "connected", "sid": sid}, to=sid)


@sio.event
async def disconnect(sid: str) -> None:
    match_id, player = await match_store.remove_player_by_sid(sid)
    print(f"[ws] client disconnected: {sid} (match={match_id})")
    if match_id:
        await _broadcast_roster(match_id)


@sio.event
async def echo(sid: str, data: dict) -> dict:
    """Round-trip check kept from Task 1 for debugging."""
    await sio.emit("echo_back", {"you_sent": data}, to=sid)
    return {"ok": True, "echoed": data}


async def _broadcast_roster(match_id: str) -> None:
    """Tell everyone in the room who is currently seated."""
    players = await match_store.get_players(match_id)
    await sio.emit(
        "roster",
        {
            "match_id": match_id,
            "players": [
                {"seat": p["seat"], "name": p["name"], "is_bot": p["is_bot"],
                 "connected": p["sid"] is not None}
                for p in players
            ],
        },
        room=match_id,
    )


@sio.event
async def find_match(sid: str, data: dict) -> dict:
    """Seat this player into a match, backfill bots to fill the table, and
    start it. Task 2 keeps matchmaking trivial: one fresh match per request.
    Real skill/gender/category matchmaking arrives in a later task.

    data: { user_id, name, difficulty? }
    """
    user_id = (data or {}).get("user_id") or f"guest-{sid[:6]}"
    name = (data or {}).get("name") or "Player"
    difficulty = (data or {}).get("difficulty") or "easy"

    # Provision durable DB rows so attempts have valid foreign keys.
    async with SessionLocal() as db:
        db_match_id = await game_repo.create_db_match(db, difficulty)
        db_user_id = await game_repo.create_db_user(db, name)
        await game_repo.add_match_player(db, db_match_id, db_user_id)
        await db.commit()

    # Redis live-state match keyed by the SAME id as the DB match row.
    match_id = await match_store.create_match(difficulty=difficulty, match_id=db_match_id)

    player = await match_store.add_player(
        match_id, sid=sid, user_id=db_user_id, name=name, is_bot=False
    )
    await sio.enter_room(sid, match_id)

    # Fill the remaining seats with bots so a full 4-player table can start.
    await match_store.fill_with_bots(match_id)
    await match_store.set_status(match_id, "active")

    await _broadcast_roster(match_id)
    await sio.emit("match_started", {"match_id": match_id}, room=match_id)

    # Task 3: immediately serve the first question to the whole room.
    await _start_and_broadcast_question(match_id, difficulty=difficulty, index=0)

    return {"ok": True, "match_id": match_id, "seat": player["seat"] if player else None}


async def _start_and_broadcast_question(
    match_id: str, *, difficulty: str, index: int
) -> bool:
    """Pick a LIVE question and push it to every seat at once, with a shared
    server-controlled deadline. The correct answer is stored in Redis but is
    NEVER sent to clients."""
    import time as _t

    async with SessionLocal() as db:
        q = await game_repo.pick_live_question(db, difficulty)
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
            "total": scores.get(seat, 0),
        }
        for seat in players
    ]
    standings.sort(key=lambda s: s["total"], reverse=True)
    for placement, s in enumerate(standings, start=1):
        s["placement"] = placement

    # Persist final score + placement for real (non-bot) players.
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
            except Exception as e:  # noqa: BLE001
                print(f"[ws] placement persist skipped (seat {s['seat']}): {e}")
        await db.commit()

    await sio.emit(
        "match_over",
        {"match_id": match_id, "standings": standings},
        room=match_id,
    )


@sio.event
async def leave_match(sid: str, data: dict | None = None) -> dict:
    match_id, _ = await match_store.remove_player_by_sid(sid)
    if match_id:
        await sio.leave_room(sid, match_id)
        await _broadcast_roster(match_id)
    return {"ok": True}