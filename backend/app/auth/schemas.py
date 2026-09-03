from __future__ import annotations

import datetime as dt

from pydantic import BaseModel, EmailStr, Field
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession


class RegisterIn(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    display_name: str = Field(min_length=1, max_length=64)
    gender: str  # required for same-gender matchmaking
    # Only "player" or "teacher" may be self-registered; admin/scholar/developer
    # accounts are provisioned out-of-band, never through this public endpoint.
    role: str = "player"

    @property
    def gender_ok(self) -> bool:
        return self.gender in ("male", "female")

    @property
    def role_ok(self) -> bool:
        return self.role in ("player", "teacher")


class LoginIn(BaseModel):
    email: EmailStr
    password: str


class GuestIn(BaseModel):
    display_name: str = Field(min_length=1, max_length=64)
    gender: str


class AccountDeleteIn(BaseModel):
    # Only required for accounts that have a password (guests have none).
    password: str | None = None


class ForgotPasswordIn(BaseModel):
    email: EmailStr


class ResetPasswordIn(BaseModel):
    token: str
    new_password: str = Field(min_length=8, max_length=128)


class MeOut(BaseModel):
    user_id: str
    display_name: str
    role: str
    gender: str | None = None


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: str
    display_name: str
    role: str


# ---- repository ----

async def get_user_by_email(db: AsyncSession, email: str) -> dict | None:
    row = (
        await db.execute(
            text(
                "SELECT id, display_name, role::text AS role, password_hash "
                "FROM users WHERE email = :e"
            ),
            {"e": email.lower()},
        )
    ).mappings().first()
    return dict(row) if row else None


async def create_user(
    db: AsyncSession,
    *,
    email: str,
    display_name: str,
    gender: str,
    password_hash: str,
    role: str = "player",
) -> dict:
    row = (
        await db.execute(
            text(
                """
                INSERT INTO users (role, email, display_name, gender, password_hash)
                VALUES (CAST(:role AS user_role), :e, :n, CAST(:g AS gender_type), :ph)
                RETURNING id, display_name, role::text AS role
                """
            ),
            {
                "role": role,
                "e": email.lower(),
                "n": display_name,
                "g": gender,
                "ph": password_hash,
            },
        )
    ).mappings().one()
    return dict(row)


async def get_user_by_id(db: AsyncSession, user_id: str) -> dict | None:
    row = (
        await db.execute(
            text(
                "SELECT id, display_name, role::text AS role, gender "
                "FROM users WHERE id = :id"
            ),
            {"id": user_id},
        )
    ).mappings().first()
    return dict(row) if row else None


async def get_password_hash(db: AsyncSession, user_id: str) -> str | None:
    row = (
        await db.execute(text("SELECT password_hash FROM users WHERE id = :id"), {"id": user_id})
    ).first()
    return row[0] if row else None


async def delete_user(db: AsyncSession, user_id: str) -> None:
    """Every FK referencing users(id) is ON DELETE CASCADE or SET NULL — this
    is the whole deletion, no manual cascade cleanup needed."""
    await db.execute(text("DELETE FROM users WHERE id = :id"), {"id": user_id})


async def set_reset_token(db: AsyncSession, email: str, token: str, expires_at: dt.datetime) -> bool:
    """Sets a fresh reset token for the account with this email, if one
    exists. Returns whether a matching account was found (used only to
    decide whether to send an email — never exposed to the caller of the
    /forgot-password endpoint, which always responds identically either way
    to avoid leaking which emails are registered)."""
    result = await db.execute(
        text(
            "UPDATE users SET password_reset_token = :t, password_reset_expires_at = :e "
            "WHERE email = :e_addr"
        ),
        {"t": token, "e": expires_at, "e_addr": email.lower()},
    )
    return result.rowcount > 0


async def get_user_by_reset_token(db: AsyncSession, token: str) -> dict | None:
    row = (
        await db.execute(
            text("SELECT id, password_reset_expires_at FROM users WHERE password_reset_token = :t"),
            {"t": token},
        )
    ).mappings().first()
    return dict(row) if row else None


async def apply_password_reset(db: AsyncSession, user_id: str, password_hash: str) -> None:
    await db.execute(
        text(
            "UPDATE users SET password_hash = :ph, password_reset_token = NULL, "
            "password_reset_expires_at = NULL WHERE id = :id"
        ),
        {"ph": password_hash, "id": user_id},
    )


async def create_guest(db: AsyncSession, *, display_name: str, gender: str) -> dict:
    """A passwordless guest account (email + password_hash NULL)."""
    row = (
        await db.execute(
            text(
                """
                INSERT INTO users (role, display_name, gender)
                VALUES ('player', :n, CAST(:g AS gender_type))
                RETURNING id, display_name, role::text AS role
                """
            ),
            {"n": display_name, "g": gender},
        )
    ).mappings().one()
    return dict(row)