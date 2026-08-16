from fastapi import APIRouter
from sqlalchemy import text

from ..db import engine
from ..redis_client import redis_client

router = APIRouter()


@router.get("/health")
async def health() -> dict:
    """Liveness + dependency check: the backend is only 'ok' if it can
    actually reach Postgres and Redis."""
    db_ok = False
    redis_ok = False

    try:
        async with engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
        db_ok = True
    except Exception:
        db_ok = False

    try:
        redis_ok = bool(await redis_client.ping())
    except Exception:
        redis_ok = False

    return {
        "status": "ok" if (db_ok and redis_ok) else "degraded",
        "db": db_ok,
        "redis": redis_ok,
    }