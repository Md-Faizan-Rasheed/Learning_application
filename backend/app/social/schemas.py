from __future__ import annotations

from uuid import UUID

from pydantic import BaseModel, Field


class MyCodeOut(BaseModel):
    friend_code: str


class FriendRequestCreate(BaseModel):
    friend_code: str = Field(min_length=4, max_length=16)


class FriendRequestByUserIn(BaseModel):
    user_id: UUID


class FriendRequestSentOut(BaseModel):
    id: UUID
    to_display_name: str
    status: str


class FriendRequestOut(BaseModel):
    id: UUID
    from_user_id: UUID
    display_name: str
    total_xp: int


class RespondIn(BaseModel):
    accept: bool


class FriendOut(BaseModel):
    id: UUID
    display_name: str
    total_xp: int
    streak_days: int


class ChallengeCreate(BaseModel):
    opponent_id: UUID
    category: str = "mixed"
    question_count: int = Field(default=8, ge=1, le=20)


class ChallengeOut(BaseModel):
    id: UUID
    challenger_id: UUID
    challenger_name: str
    opponent_id: UUID
    opponent_name: str
    category: str
    question_count: int
    challenger_score: int | None
    opponent_score: int | None
    status: str
    winner_id: UUID | None


class ChallengeScoreIn(BaseModel):
    correct_count: int = Field(ge=0)
