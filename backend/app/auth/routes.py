from __future__ import annotations

import datetime as dt
import secrets

from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.responses import HTMLResponse
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..common.deps import CurrentUser, get_current_user, get_db
from . import schemas
from .email import send_reset_email
from .security import create_access_token, hash_password, verify_password

router = APIRouter(prefix="/auth", tags=["auth"])

_RESET_TOKEN_TTL = dt.timedelta(hours=1)


@router.post("/register", response_model=schemas.TokenOut, status_code=status.HTTP_201_CREATED)
async def register(data: schemas.RegisterIn, db: AsyncSession = Depends(get_db)) -> schemas.TokenOut:
    if not data.gender_ok:
        raise HTTPException(status_code=422, detail="gender must be 'male' or 'female'")
    if not data.role_ok:
        raise HTTPException(status_code=422, detail="role must be 'player' or 'teacher'")

    try:
        user = await schemas.create_user(
            db,
            email=data.email,
            display_name=data.display_name,
            gender=data.gender,
            password_hash=hash_password(data.password),
            role=data.role,
        )
    except IntegrityError:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail="email already registered"
        )

    token = create_access_token(user_id=str(user["id"]), role=user["role"])
    return schemas.TokenOut(
        access_token=token,
        user_id=str(user["id"]),
        display_name=user["display_name"],
        role=user["role"],
    )


@router.post("/guest", response_model=schemas.TokenOut, status_code=status.HTTP_201_CREATED)
async def guest(data: schemas.GuestIn, db: AsyncSession = Depends(get_db)) -> schemas.TokenOut:
    """Create a passwordless guest account and hand back a token. Lets a player
    play (and keep progress) before committing to email/password."""
    if data.gender not in ("male", "female"):
        raise HTTPException(status_code=422, detail="gender must be 'male' or 'female'")
    user = await schemas.create_guest(db, display_name=data.display_name, gender=data.gender)
    token = create_access_token(user_id=str(user["id"]), role=user["role"])
    return schemas.TokenOut(
        access_token=token,
        user_id=str(user["id"]),
        display_name=user["display_name"],
        role=user["role"],
    )


@router.delete("/account", status_code=status.HTTP_204_NO_CONTENT)
async def delete_account(
    data: schemas.AccountDeleteIn,
    current: CurrentUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    """Permanently and immediately deletes the caller's account and every
    row that references it (cascades — see schemas.delete_user). Accounts
    with a password must confirm it; guest accounts (no password) don't."""
    password_hash = await schemas.get_password_hash(db, current.user_id)
    if password_hash is not None:
        if not data.password or not verify_password(data.password, password_hash):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, detail="incorrect password"
            )
    await schemas.delete_user(db, current.user_id)


@router.post("/forgot-password")
async def forgot_password(
    data: schemas.ForgotPasswordIn,
    request: Request,
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Always responds the same way regardless of whether the email is
    registered, so this can't be used to enumerate accounts. Silently no-ops
    (still returns success) if the email doesn't match anyone."""
    token = secrets.token_urlsafe(32)
    expires_at = dt.datetime.now(dt.timezone.utc) + _RESET_TOKEN_TTL
    matched = await schemas.set_reset_token(db, data.email, token, expires_at)
    if matched:
        reset_url = f"{str(request.base_url).rstrip('/')}/auth/reset-password-page?token={token}"
        await send_reset_email(to=data.email, reset_url=reset_url)
    return {"message": "If that email is registered, a reset link has been sent."}


@router.get("/reset-password-page", response_class=HTMLResponse)
async def reset_password_page(token: str) -> HTMLResponse:
    """A plain server-rendered form — the emailed link opens this directly in
    a browser, no in-app deep-linking needed."""
    safe_token = token.replace('"', "").replace("'", "").replace("\\", "")
    return HTMLResponse(f"""<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>Reset your password</title>
<style>
  body {{ font-family: -apple-system, Segoe UI, Roboto, Arial, sans-serif; max-width: 420px;
         margin: 60px auto; padding: 0 20px; color: #1a1a2e; }}
  input {{ width: 100%; padding: 10px; margin: 8px 0 16px; box-sizing: border-box;
          border: 1px solid #ccc; border-radius: 8px; font-size: 15px; }}
  button {{ width: 100%; padding: 12px; background: #0d9488; color: white; border: none;
           border-radius: 8px; font-size: 15px; cursor: pointer; }}
  #msg {{ margin-top: 14px; font-size: 14px; }}
</style></head>
<body>
<h2>Reset your password</h2>
<form id="f">
  <label>New password</label>
  <input type="password" id="pw" minlength="8" required>
  <button type="submit">Set new password</button>
</form>
<p id="msg"></p>
<script>
document.getElementById('f').addEventListener('submit', async (e) => {{
  e.preventDefault();
  const pw = document.getElementById('pw').value;
  const res = await fetch('/auth/reset-password', {{
    method: 'POST',
    headers: {{'Content-Type': 'application/json'}},
    body: JSON.stringify({{token: "{safe_token}", new_password: pw}})
  }});
  const msg = document.getElementById('msg');
  if (res.ok) {{
    msg.textContent = 'Password updated \\u2014 you can now sign in with your new password.';
    document.getElementById('f').style.display = 'none';
  }} else {{
    const data = await res.json().catch(() => ({{}}));
    msg.textContent = (data.detail || 'This link is invalid or has expired.').toString();
  }}
}});
</script>
</body></html>""")


@router.post("/reset-password")
async def reset_password(
    data: schemas.ResetPasswordIn,
    db: AsyncSession = Depends(get_db),
) -> dict:
    user = await schemas.get_user_by_reset_token(db, data.token)
    expires_at = user["password_reset_expires_at"] if user else None
    if not user or expires_at is None or expires_at < dt.datetime.now(dt.timezone.utc):
        raise HTTPException(status_code=400, detail="This reset link is invalid or has expired.")
    await schemas.apply_password_reset(db, str(user["id"]), hash_password(data.new_password))
    return {"message": "Password updated."}


@router.get("/me", response_model=schemas.MeOut)
async def me(
    current: CurrentUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> schemas.MeOut:
    """Return the authenticated user's profile (validates the token)."""
    user = await schemas.get_user_by_id(db, current.user_id)
    if not user:
        raise HTTPException(status_code=404, detail="user not found")
    return schemas.MeOut(
        user_id=str(user["id"]),
        display_name=user["display_name"],
        role=user["role"],
        gender=user.get("gender"),
    )


@router.post("/login", response_model=schemas.TokenOut)
async def login(data: schemas.LoginIn, db: AsyncSession = Depends(get_db)) -> schemas.TokenOut:
    user = await schemas.get_user_by_email(db, data.email)
    # Same generic error whether the email is unknown or the password is wrong,
    # so we don't leak which emails are registered.
    if not user or not user.get("password_hash") or not verify_password(
        data.password, user["password_hash"]
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="invalid email or password"
        )

    token = create_access_token(user_id=str(user["id"]), role=user["role"])
    return schemas.TokenOut(
        access_token=token,
        user_id=str(user["id"]),
        display_name=user["display_name"],
        role=user["role"],
    )