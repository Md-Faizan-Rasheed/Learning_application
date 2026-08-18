from __future__ import annotations

from uuid import UUID

from pydantic import BaseModel, Field

SUPPORTED_LANGS = ("en", "ur", "ar")


class ServedQuestion(BaseModel):
    """A question as the CLIENT sees it — note there is NO correct answer here.
    The server withholds it until the player has submitted (anti-cheat)."""

    question_id: UUID
    match_id: UUID
    difficulty: str
    lang: str
    prompt: str
    options: list[str]
    time_ms: int


class AnswerIn(BaseModel):
    match_id: UUID
    question_id: UUID
    # index of the option the player chose; null = timed out with no choice
    chosen_index: int | None = Field(default=None, ge=0)
    # client-measured elapsed time; the server treats this as advisory only
    response_ms: int | None = Field(default=None, ge=0)


class AnswerResult(BaseModel):
    is_correct: bool
    correct_index: int
    points_awarded: int
    # echoed so the client can show the right answer AFTER submitting
    correct_option: str