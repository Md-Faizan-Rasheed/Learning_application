from __future__ import annotations

from uuid import UUID

from pydantic import BaseModel, Field, field_validator, model_validator

# The category list shape is identical to the admin one, reused as-is.
from ..content.schemas import CategoryOut  # noqa: F401

# Teacher-authored questions are single-language (Google-Forms style: just
# type the question, no translation required) — a deliberate simplification
# from the admin bank's trilingual QuestionCreate. The single string is
# stored under every SUPPORTED_LANGS key (see repository.create_teacher_question)
# so it still fits the existing per-language JSONB storage and is served
# identically regardless of which language the student's app is set to.
_DEFAULT_DIFFICULTY = "medium"


class TeacherQuestionCreate(BaseModel):
    category_id: UUID
    prompt: str = Field(min_length=1, max_length=2000)
    options: list[str] = Field(min_length=2, max_length=10)
    correct_index: int = Field(ge=0)

    @field_validator("options")
    @classmethod
    def options_nonempty(cls, v: list[str]) -> list[str]:
        cleaned = [o.strip() for o in v]
        if any(not o for o in cleaned):
            raise ValueError("options must not be empty")
        return cleaned

    @model_validator(mode="after")
    def correct_index_in_range(self) -> "TeacherQuestionCreate":
        if self.correct_index >= len(self.options):
            raise ValueError(
                f"correct_index {self.correct_index} out of range (0..{len(self.options) - 1})"
            )
        return self


class ClassCreate(BaseModel):
    name: str = Field(min_length=1, max_length=128)


class ClassOut(BaseModel):
    id: UUID
    name: str
    join_code: str
    student_count: int


class ClassStudentOut(BaseModel):
    student_id: UUID
    display_name: str


class ClassDetailOut(BaseModel):
    id: UUID
    name: str
    join_code: str
    students: list[ClassStudentOut]


class TeacherQuestionOut(BaseModel):
    id: UUID
    category_id: UUID
    difficulty: str
    prompt: dict
    options: dict
    correct_index: int
    source: str | None


class AiImportRequest(BaseModel):
    category_id: UUID
    text: str = Field(min_length=1, max_length=20000)


class AiQuestionOut(TeacherQuestionOut):
    note: str | None = None


class AiImportResult(BaseModel):
    questions: list[AiQuestionOut]


class BankQuestionOut(BaseModel):
    id: UUID
    category_id: UUID
    difficulty: str
    prompt: dict
    options: dict
    correct_index: int


class QuizCreate(BaseModel):
    title: str = Field(min_length=1, max_length=128)
    class_id: UUID
    time_limit_ms: int = Field(default=20000, ge=1000, le=120000)
    question_ids: list[UUID] = Field(min_length=1, max_length=50)

    @field_validator("question_ids")
    @classmethod
    def no_duplicates(cls, v: list[UUID]) -> list[UUID]:
        if len(set(v)) != len(v):
            raise ValueError("question_ids must not contain duplicates")
        return v


class QuizOut(BaseModel):
    id: UUID
    class_id: UUID
    title: str
    time_limit_ms: int
    status: str
    question_count: int


class QuizStudentResult(BaseModel):
    student_id: UUID
    display_name: str
    status: str  # not_started | in_progress | completed
    score: int | None
    correct_count: int | None
    total_questions: int | None


class QuizResultsOut(BaseModel):
    quiz: QuizOut
    students: list[QuizStudentResult]
    average_score: float | None
    completion_rate: float
