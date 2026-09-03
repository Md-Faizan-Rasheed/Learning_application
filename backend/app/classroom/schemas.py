from __future__ import annotations

from uuid import UUID

from pydantic import BaseModel, Field

SUPPORTED_LANGS = ("en", "ur", "ar")


class JoinIn(BaseModel):
    join_code: str = Field(min_length=1, max_length=16)


class JoinOut(BaseModel):
    class_id: UUID
    class_name: str


class AssignedQuizOut(BaseModel):
    quiz_id: UUID
    title: str
    class_name: str
    question_count: int
    attempt_status: str  # not_started | in_progress | completed
    score: int | None


class ServedQuizQuestion(BaseModel):
    """Mirrors game.schemas.ServedQuestion: the correct answer is withheld."""

    quiz_id: UUID
    question_id: UUID
    lang: str
    prompt: str
    options: list[str]
    time_limit_ms: int
    question_no: int  # 1-based position in the quiz
    total_questions: int


class AnswerIn(BaseModel):
    question_id: UUID
    chosen_index: int | None = Field(default=None, ge=0)
    response_ms: int | None = Field(default=None, ge=0)


class AnswerResult(BaseModel):
    is_correct: bool
    correct_index: int
    points_awarded: int
    correct_option: str
    quiz_complete: bool


class QuizResultOut(BaseModel):
    quiz_id: UUID
    title: str
    score: int
    correct_count: int
    total_questions: int
