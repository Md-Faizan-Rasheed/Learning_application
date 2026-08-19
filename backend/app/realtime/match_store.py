"""Live match state, held in Redis (the authoritative store for an in-progress
match). Postgres still owns durable records (matches, match_players rows are
written when a match forms); Redis holds the fast, ephemeral seat/roster state.

Key shape:
  match:{match_id}:meta     -> hash: status, difficulty, category, created_at
  match:{match_id}:players  -> hash: seat_index -> json(player)  (player = {sid,user_id,is_bot,name})
  sid:{sid}                 -> string: match_id  (reverse lookup for disconnects)

Everything here is keyed by match_id so it survives a single game-server
instance dying — any instance can rebuild a match from these keys.
"""

from __future__ import annotations

import json
import time
import uuid

from ..redis_client import redis_client

MAX_SEATS = 4
_TTL_SECONDS = 60 * 60  # safety expiry so abandoned matches self-clean
ROUNDS_PER_MATCH = 5  # a match plays this many questions, then ends


def _meta_key(match_id: str) -> str:
    return f"match:{match_id}:meta"


def _players_key(match_id: str) -> str:
    return f"match:{match_id}:players"


def _sid_key(sid: str) -> str:
    return f"sid:{sid}"


def _round_key(match_id: str) -> str:
    return f"match:{match_id}:round"


def _answers_key(match_id: str, round_no: int) -> str:
    return f"match:{match_id}:round:{round_no}:answers"


def _scores_key(match_id: str) -> str:
    return f"match:{match_id}:scores"


# ---- matchmaking lobby (pools humans before a match starts) ----
# open:{difficulty} -> match_id of the currently-forming lobby (if any)

def _open_key(difficulty: str) -> str:
    return f"open:{difficulty}"


async def find_open_match(difficulty: str) -> str | None:
    """The match_id of a lobby currently accepting players for this difficulty."""
    return await redis_client.get(_open_key(difficulty))


async def set_open_match(difficulty: str, match_id: str) -> None:
    # short-lived pointer; the lobby closes when it fills or the timer fires
    await redis_client.set(_open_key(difficulty), match_id, ex=_TTL_SECONDS)


async def clear_open_match(difficulty: str, match_id: str) -> None:
    """Stop new players joining this lobby — but only if it's still the open one
    (compare-and-delete, so we don't clobber a newer lobby)."""
    current = await redis_client.get(_open_key(difficulty))
    if current == match_id:
        await redis_client.delete(_open_key(difficulty))


async def try_claim_open_seat(difficulty: str) -> str | None:
    """Atomically get the open lobby for this difficulty, or None. (Read is
    atomic enough here; seat contention is handled by add_player returning None
    when full.)"""
    return await redis_client.get(_open_key(difficulty))


async def count_humans(match_id: str) -> int:
    raw = await redis_client.hgetall(_players_key(match_id))
    return sum(1 for v in raw.values() if not json.loads(v)["is_bot"])


async def reseat_player(match_id: str, user_id: str, new_sid: str) -> dict | None:
    """On reconnect: find the seat this user_id already holds and reattach the
    new socket id to it. Returns the player, or None if they're not in the match."""
    raw = await redis_client.hgetall(_players_key(match_id))
    for seat, v in raw.items():
        p = json.loads(v)
        if p.get("user_id") == user_id:
            p["sid"] = new_sid
            await redis_client.hset(_players_key(match_id), seat, json.dumps(p))
            await redis_client.set(_sid_key(new_sid), match_id, ex=_TTL_SECONDS)
            return p
    return None


async def has_answered(match_id: str, round_no: int, seat: int) -> bool:
    return bool(
        await redis_client.hexists(_answers_key(match_id, round_no), str(seat))
    )


async def create_match(
    difficulty: str = "easy", category: str | None = None, match_id: str | None = None
) -> str:
    match_id = match_id or str(uuid.uuid4())
    await redis_client.hset(
        _meta_key(match_id),
        mapping={
            "status": "waiting",
            "difficulty": difficulty,
            "category": category or "",
            "created_at": str(int(time.time())),
        },
    )
    await redis_client.expire(_meta_key(match_id), _TTL_SECONDS)
    return match_id


async def get_players(match_id: str) -> list[dict]:
    raw = await redis_client.hgetall(_players_key(match_id))
    players = [json.loads(v) for v in raw.values()]
    players.sort(key=lambda p: p["seat"])
    return players


async def add_player(
    match_id: str, *, sid: str | None, user_id: str, name: str, is_bot: bool = False
) -> dict | None:
    """Seat a player in the first free seat. Returns the seated player, or None
    if the match is already full."""
    existing = await redis_client.hgetall(_players_key(match_id))
    taken = {json.loads(v)["seat"] for v in existing.values()}
    seat = next((i for i in range(MAX_SEATS) if i not in taken), None)
    if seat is None:
        return None

    player = {"seat": seat, "sid": sid, "user_id": user_id, "name": name, "is_bot": is_bot}
    await redis_client.hset(_players_key(match_id), str(seat), json.dumps(player))
    await redis_client.expire(_players_key(match_id), _TTL_SECONDS)
    if sid:
        await redis_client.set(_sid_key(sid), match_id, ex=_TTL_SECONDS)
    return player


async def fill_with_bots(match_id: str) -> list[dict]:
    """Fill all remaining seats with bots so the match can start. Returns the
    bots that were added."""
    added: list[dict] = []
    while True:
        bot = await add_player(
            match_id,
            sid=None,
            user_id=f"bot-{uuid.uuid4().hex[:8]}",
            name="Bot",
            is_bot=True,
        )
        if bot is None:
            break
        added.append(bot)
    return added


async def match_id_for_sid(sid: str) -> str | None:
    return await redis_client.get(_sid_key(sid))


async def remove_player_by_sid(sid: str) -> tuple[str | None, dict | None]:
    """On disconnect: find the player's match + seat, mark them disconnected.
    We do NOT free the seat immediately (reconnect grace comes in a later task);
    for now we just clear the sid mapping and flag the player."""
    match_id = await redis_client.get(_sid_key(sid))
    if not match_id:
        return None, None
    raw = await redis_client.hgetall(_players_key(match_id))
    for seat, v in raw.items():
        p = json.loads(v)
        if p.get("sid") == sid:
            p["sid"] = None  # mark disconnected, keep the seat
            await redis_client.hset(_players_key(match_id), seat, json.dumps(p))
            await redis_client.delete(_sid_key(sid))
            return match_id, p
    await redis_client.delete(_sid_key(sid))
    return match_id, None


async def set_status(match_id: str, status: str) -> None:
    await redis_client.hset(_meta_key(match_id), "status", status)


async def start_round(
    match_id: str,
    *,
    question_id: str,
    correct_index: int,
    difficulty: str,
    prompt: dict,
    options: dict,
    time_ms: int,
    round_no: int,
) -> None:
    """Store the active round server-side. The correct_index lives here (server
    only) and is NEVER broadcast to clients until answers resolve."""
    import time as _t

    await redis_client.hset(
        _round_key(match_id),
        mapping={
            "question_id": question_id,
            "correct_index": str(correct_index),
            "difficulty": difficulty,
            "prompt": json.dumps(prompt),
            "options": json.dumps(options),
            "time_ms": str(time_ms),
            "round_no": str(round_no),
            "started_at_ms": str(int(_t.time() * 1000)),
        },
    )
    await redis_client.expire(_round_key(match_id), _TTL_SECONDS)


async def get_round(match_id: str) -> dict | None:
    raw = await redis_client.hgetall(_round_key(match_id))
    if not raw:
        return None
    raw["prompt"] = json.loads(raw["prompt"])
    raw["options"] = json.loads(raw["options"])
    raw["correct_index"] = int(raw["correct_index"])
    raw["time_ms"] = int(raw["time_ms"])
    raw["round_no"] = int(raw["round_no"])
    raw["started_at_ms"] = int(raw["started_at_ms"])
    return raw


async def get_meta(match_id: str) -> dict:
    return await redis_client.hgetall(_meta_key(match_id))


async def record_answer(
    match_id: str, round_no: int, seat: int, payload: dict
) -> bool:
    """Record a seat's answer for this round exactly once. Returns True if this
    was a new answer, False if the seat already answered (idempotency guard).
    Uses HSETNX so a double-submit can't overwrite the first answer."""
    added = await redis_client.hsetnx(
        _answers_key(match_id, round_no), str(seat), json.dumps(payload)
    )
    await redis_client.expire(_answers_key(match_id, round_no), _TTL_SECONDS)
    return bool(added)


async def get_answers(match_id: str, round_no: int) -> dict[int, dict]:
    raw = await redis_client.hgetall(_answers_key(match_id, round_no))
    return {int(seat): json.loads(v) for seat, v in raw.items()}


async def add_score(match_id: str, seat: int, points: int) -> int:
    """Add points to a seat's running total; returns the new total."""
    return int(
        await redis_client.hincrby(_scores_key(match_id), str(seat), points)
    )


async def get_scores(match_id: str) -> dict[int, int]:
    raw = await redis_client.hgetall(_scores_key(match_id))
    return {int(seat): int(v) for seat, v in raw.items()}