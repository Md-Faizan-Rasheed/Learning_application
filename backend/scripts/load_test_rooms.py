"""Exercise Socket.IO create-room, join-room, and full-match flows.

Examples (run from the repo root):
  python backend/scripts/load_test_rooms.py --rooms 1 --parallel-rooms 1
  python backend/scripts/load_test_rooms.py --url https://STAGING_HOST \
      --confirm-staging --rooms 10 --parallel-rooms 5 --seats 4

Remote targets require --confirm-staging. Use a dedicated staging database and
Redis: each simulated player and match is persisted by the application.
"""

from __future__ import annotations

import argparse
import asyncio
import random
import statistics
import time
import uuid
from collections import defaultdict
from urllib.parse import urlparse

import socketio

ROUNDS_PER_MATCH = 8
VALID_SEATS = (4, 6, 8)


class SimulatedPlayer:
    def __init__(self, name: str, timeout: float) -> None:
        self.name = name
        self.timeout = timeout
        self.client = socketio.AsyncClient(
            reconnection=False,
            logger=False,
            engineio_logger=False,
        )
        self.questions: asyncio.Queue[dict] = asyncio.Queue()
        self.results: asyncio.Queue[dict] = asyncio.Queue()
        self.match_overs: asyncio.Queue[dict] = asyncio.Queue()

        self.client.on("question", self._on_question)
        self.client.on("round_result", self._on_result)
        self.client.on("match_over", self._on_match_over)

    async def _on_question(self, data: dict) -> None:
        await self.questions.put(data)

    async def _on_result(self, data: dict) -> None:
        await self.results.put(data)

    async def _on_match_over(self, data: dict) -> None:
        await self.match_overs.put(data)

    async def receive(self, queue: asyncio.Queue[dict], label: str) -> dict:
        try:
            return await asyncio.wait_for(queue.get(), timeout=self.timeout)
        except asyncio.TimeoutError as exc:
            raise TimeoutError(f"{self.name}: timed out waiting for {label}") from exc

class LoadRun:

    def __init__(self, url: str, timeout: float) -> None:
        self.url = url
        self.timeout = timeout
        self.latencies: dict[str, list[float]] = defaultdict(list)

    async def call(self, player: SimulatedPlayer, event: str, data: dict) -> dict:
        started = time.perf_counter()
        reply = await player.client.call(event, data, timeout=self.timeout)
        self.latencies[event].append((time.perf_counter() - started) * 1000)
        if not isinstance(reply, dict) or reply.get("ok") is not True:
            detail = reply.get("error", "invalid acknowledgement") if isinstance(reply, dict) else repr(reply)
            raise RuntimeError(f"{event} failed for {player.name}: {detail}")
        return reply

    async def run_room(self, room_number: int, seats: int, difficulty: str) -> None:
        run_tag = uuid.uuid4().hex[:6]
        players = [
            SimulatedPlayer(f"Load-{run_tag}-{room_number}-{seat + 1}", self.timeout)
            for seat in range(seats)
        ]
        try:
            # Connect before creating/joining so all room broadcasts are observed.
            await asyncio.gather(*(
                player.client.connect(
                    self.url,
                    auth={},
                    transports=["websocket"],
                    wait_timeout=self.timeout,
                )
                for player in players
            ))

            host = players[0]
            created = await self.call(host, "create_room", {
                "name": host.name,
                "difficulty": difficulty,
                "category": "seerah",
                "max_seats": seats,
            })
            room_code = created.get("room_code")
            if not room_code:
                raise RuntimeError("create_room succeeded without a room code")

            # Join in sequence: the current Redis seat allocator is not an atomic
            # multi-writer operation, so simultaneous joins could race for seats.
            for player in players[1:]:
                await self.call(player, "join_room", {
                    "name": player.name,
                    "room_code": room_code,
                })

            await self.call(host, "start_room", {})

            rng = random.Random(f"{run_tag}-{room_number}")
            for round_number in range(ROUNDS_PER_MATCH):
                questions = await asyncio.gather(*(
                    player.receive(player.questions, "question") for player in players
                ))
                if any(q.get("index") != round_number for q in questions):
                    raise RuntimeError(f"room {room_number}: unexpected question index")

                async def answer(player: SimulatedPlayer, question: dict) -> None:
                    options = question.get("options", {}).get("en", [])
                    if not options:
                        raise RuntimeError(f"{player.name}: question has no answer options")
                    await self.call(player, "submit_answer", {
                        "chosen_index": rng.randrange(len(options)),
                    })

                await asyncio.gather(*(
                    answer(player, question)
                    for player, question in zip(players, questions)
                ))
                results = await asyncio.gather(*(
                    player.receive(player.results, "round_result") for player in players
                ))
                if any(r.get("round_no") != round_number for r in results):
                    raise RuntimeError(f"room {room_number}: unexpected round result")

            await asyncio.gather(*(
                player.receive(player.match_overs, "match_over") for player in players
            ))
        finally:
            await asyncio.gather(*(
                player.client.disconnect()
                for player in players
                if player.client.connected
            ), return_exceptions=True)

    def print_summary(self, rooms: int, seats: int, failures: list[str]) -> None:
        print(f"Completed rooms: {rooms - len(failures)}/{rooms}")
        print(f"Simulated players: {rooms * seats}")
        if failures:
            print(f"Failed rooms: {len(failures)}")
            for failure in failures:
                print(f"  - {failure}")
        print("Socket.IO acknowledgement latency (ms):")
        for event, samples in sorted(self.latencies.items()):
            ordered = sorted(samples)
            p95_index = min(len(ordered) - 1, int(len(ordered) * 0.95))
            print(
                f"  {event}: n={len(ordered)} "
                f"p50={statistics.median(ordered):.1f} "
                f"p95={ordered[p95_index]:.1f} max={max(ordered):.1f}"
            )

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", default="http://127.0.0.1:8000", help="Backend base URL")
    parser.add_argument("--rooms", type=int, default=1, help="Total rooms to create")
    parser.add_argument("--parallel-rooms", type=int, default=1,
                        help="Rooms active concurrently; peak clients = this × seats")
    parser.add_argument("--seats", type=int, choices=VALID_SEATS, default=4,
                        help="Room capacity: 4, 6, or 8 players")
    parser.add_argument("--difficulty", choices=("easy", "medium", "hard"), default="easy")
    parser.add_argument("--timeout", type=float, default=45,
                        help="Seconds to wait for a Socket.IO ack or game event")
    parser.add_argument("--confirm-staging", action="store_true",
                        help="Confirm that a non-local target is a dedicated staging system")
    args = parser.parse_args()

    if args.rooms < 1 or args.parallel_rooms < 1:
        parser.error("--rooms and --parallel-rooms must be at least 1")
    if args.timeout <= 0:
        parser.error("--timeout must be positive")
    parsed = urlparse(args.url)
    if parsed.scheme not in ("http", "https") or not parsed.hostname:
        parser.error("--url must be an http(s) backend URL")
    if parsed.hostname.lower() not in {"localhost", "127.0.0.1", "::1"} and not args.confirm_staging:
        parser.error("remote targets require --confirm-staging; use a dedicated staging DB/Redis")
    return args

async def main() -> int:
    args = parse_args()
    run = LoadRun(args.url.rstrip("/"), args.timeout)
    semaphore = asyncio.Semaphore(args.parallel_rooms)
    failures: list[str] = []

    async def bounded_room(index: int) -> None:
        async with semaphore:
            try:
                await run.run_room(index, args.seats, args.difficulty)
                print(f"Room {index}: completed")
            except Exception as exc:  # report a failed room and continue the run
                failures.append(f"room {index}: {type(exc).__name__}: {exc}")
                print(f"Room {index}: FAILED ({type(exc).__name__}: {exc})")

    started = time.perf_counter()
    await asyncio.gather(*(bounded_room(i + 1) for i in range(args.rooms)))
    elapsed = time.perf_counter() - started
    run.print_summary(args.rooms, args.seats, failures)
    print(f"Elapsed: {elapsed:.1f}s")
    return 1 if failures else 0

if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
