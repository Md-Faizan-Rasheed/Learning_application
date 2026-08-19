from __future__ import annotations

from pydantic import BaseModel, EmailStr, Field
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession


class RegisterIn(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    display_name: str = Field(min_length=1, max_length=64)
    gender: str  # required for same-gender matchmaking

    @property
    def gender_ok(self) -> bool:
        return self.gender in ("male", "female")


class LoginIn(BaseModel):
    email: EmailStr
    password: str


class GuestIn(BaseModel):
    display_name: str = Field(min_length=1, max_length=64)
    gender: str


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
    db: AsyncSession, *, email: str, display_name: str, gender: str, password_hash: str
) -> dict:
    row = (
        await db.execute(
            text(
                """
                INSERT INTO users (role, email, display_name, gender, password_hash)
                VALUES ('player', :e, :n, CAST(:g AS gender_type), :ph)
                RETURNING id, display_name, role::text AS role
                """
            ),
            {"e": email.lower(), "n": display_name, "g": gender, "ph": password_hash},
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