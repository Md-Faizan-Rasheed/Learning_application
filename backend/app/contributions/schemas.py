from __future__ import annotations

from uuid import UUID

from pydantic import BaseModel, Field, field_validator, model_validator

# Same single-language, Google-Forms-style shape as TeacherQuestionCreate
# (backend/app/teacher/schemas.py) — casual contributors aren't scholars, so
# there's no per-language translation step here either. The one string is
# stored under every supported language key at insert time.
_DEFAULT_DIFFICULTY = "medium"


class ContributionCreate(BaseModel):
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
    def correct_index_in_range(self) -> "ContributionCreate":
        if self.correct_index >= len(self.options):
            raise ValueError(
                f"correct_index {self.correct_index} out of range (0..{len(self.options) - 1})"
            )
        return self


class ContributionOut(BaseModel):
    id: UUID
    category_id: UUID
    difficulty: str
    review_state: str
    prompt: dict
    options: dict
    correct_index: int
