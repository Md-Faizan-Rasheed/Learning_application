"""Simple Redis fixed-window rate limiter — brute-force protection for auth
endpoints without adding new infra (Redis is already required for match
state; see realtime/match_store.py).

Deliberately minimal: one counter, one window, raises directly. This isn't
meant to grow into a general-purpose limiter for the whole API — reach for
slowapi (or a proper token-bucket) if more than a handful of routes need
this, or if different routes need different keying strategies.
"""

from __future__ import annotations

from fastapi import HTTPException, status

from ..redis_client import redis_client


async def rate_limit(*, key: str, limit: int, window_seconds: int) -> None:
    """Raises 429 (with a Retry-After header) once more than `limit` calls
    land under this key within `window_seconds`. Call once per request, at
    the top of a route, before doing any real work.

    Fixed-window via INCR+EXPIRE, issued as one MULTI/EXEC pipeline so a
    process restart (e.g. uvicorn --reload) can never land between the two
    commands and leave the key stuck at a high count with no TTL — that
    previously meant a key made so could never reset. EXPIRE's NX flag also
    makes this idempotent: only sets the TTL if the key doesn't already have
    one, so later hits in the same window don't keep pushing the reset time
    back.
    """
    full_key = f"ratelimit:{key}"
    pipe = redis_client.pipeline()
    pipe.incr(full_key)
    pipe.expire(full_key, window_seconds, nx=True)
    count, _ = await pipe.execute()
    if count > limit:
        retry_after = await redis_client.ttl(full_key)
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many attempts. Please try again later.",
            headers={"Retry-After": str(max(retry_after, 1))},
        )
