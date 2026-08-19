from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..common.deps import CurrentUser, get_current_user, get_db
from . import schemas
from .security import create_access_token, hash_password, verify_password

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=schemas.TokenOut, status_code=status.HTTP_201_CREATED)
async def register(data: schemas.RegisterIn, db: AsyncSession = Depends(get_db)) -> schemas.TokenOut:
    if not data.gender_ok:
        raise HTTPException(status_code=422, detail="gender must be 'male' or 'female'")

    try:
        user = await schemas.create_user(
            db,
            email=data.email,
            display_name=data.display_name,
            gender=data.gender,
            password_hash=hash_password(data.password),
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