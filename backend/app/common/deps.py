from collections.abc import AsyncIterator

from fastapi import Depends, Header, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from ..config import settings
from ..db import SessionLocal


async def get_db() -> AsyncIterator[AsyncSession]:
    """Yield an async DB session, committing on success and rolling back on error."""
    async with SessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise


class CurrentUser:
    def __init__(self, user_id: str, role: str):
        self.user_id = user_id
        self.role = role


async def get_current_user(authorization: str = Header(default="")) -> CurrentUser:
    """Validate the Bearer JWT and return the authenticated user. 401 if missing
    or invalid."""
    from ..auth.security import decode_access_token

    if not authorization.lower().startswith("bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="missing bearer token",
        )
    token = authorization[7:].strip()
    payload = decode_access_token(token)
    if not payload or "sub" not in payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="invalid or expired token",
        )
    return CurrentUser(user_id=payload["sub"], role=payload.get("role", "player"))


async def get_current_user_optional(
    authorization: str = Header(default=""),
) -> CurrentUser | None:
    """Like get_current_user but returns None instead of raising when there's no
    valid token. Lets endpoints accept alternative auth (e.g. the legacy key)."""
    from ..auth.security import decode_access_token

    if not authorization.lower().startswith("bearer "):
        return None
    payload = decode_access_token(authorization[7:].strip())
    if not payload or "sub" not in payload:
        return None
    return CurrentUser(user_id=payload["sub"], role=payload.get("role", "player"))


async def require_admin_user(
    user: CurrentUser | None = Depends(get_current_user_optional),
    x_admin_key: str = Header(default=""),
) -> CurrentUser:
    """Admin gate. Accepts either a real admin/developer JWT role, OR the legacy
    X-Admin-Key (kept temporarily for tooling/scripts until fully migrated).
    Returns 403 when neither is present/valid."""
    if user and user.role in ("admin", "developer"):
        return user
    if x_admin_key and x_admin_key == settings.admin_api_key:
        return user or CurrentUser(user_id="legacy-admin-key", role="admin")
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="admin privileges required",
    )


async def require_admin(x_admin_key: str = Header(default="")) -> None:
    """Legacy key-only gate, kept for backward compatibility."""
    if x_admin_key != settings.admin_api_key:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or missing admin key",
        )