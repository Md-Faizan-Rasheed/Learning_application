from __future__ import annotations

from uuid import UUID

from pydantic import BaseModel, Field, field_validator, model_validator

# The languages every piece of content must provide (Option B: inline i18n).
SUPPORTED_LANGS = ("en", "ur", "ar")
DIFFICULTIES = ("easy", "medium", "hard")


class CategoryCreate(BaseModel):
    slug: str = Field(min_length=1, max_length=64)
    display_name: str = Field(min_length=1, max_length=128)
    description: str | None = None

    @field_validator("slug")
    @classmethod
    def slug_is_clean(cls, v: str) -> str:
        v = v.strip().lower()
        if not v.replace("-", "").isalnum():
            raise ValueError("slug must be lowercase letters, numbers, and hyphens")
        return v


class CategoryOut(BaseModel):
    id: UUID
    slug: str
    display_name: str
    is_active: bool


class QuestionCreate(BaseModel):
    category_id: UUID
    difficulty: str
    # language -> text, e.g. {"en": "...", "ur": "...", "ar": "..."}
    prompt: dict[str, str]
    # language -> list of option strings, all lists the same length
    options: dict[str, list[str]]
    correct_index: int = Field(ge=0)
    source: str | None = None

    @field_validator("difficulty")
    @classmethod
    def valid_difficulty(cls, v: str) -> str:
        if v not in DIFFICULTIES:
            raise ValueError(f"difficulty must be one of {DIFFICULTIES}")
        return v

    @field_validator("prompt")
    @classmethod
    def prompt_all_langs(cls, v: dict[str, str]) -> dict[str, str]:
        missing = [lang for lang in SUPPORTED_LANGS if not v.get(lang, "").strip()]
        if missing:
            raise ValueError(f"prompt is missing languages: {missing}")
        return v

    @model_validator(mode="after")
    def options_consistent(self) -> "QuestionCreate":
        for lang in SUPPORTED_LANGS:
            if lang not in self.options:
                raise ValueError(f"options is missing language: {lang}")
        lengths = {len(self.options[lang]) for lang in SUPPORTED_LANGS}
        if len(lengths) != 1:
            raise ValueError("every language must list the same number of options")
        n = lengths.pop()
        if n < 2:
            raise ValueError("a question needs at least 2 options")
        if self.correct_index >= n:
            raise ValueError(f"correct_index {self.correct_index} out of range (0..{n - 1})")
        return self


class QuestionOut(BaseModel):
    id: UUID
    category_id: UUID
    difficulty: str
    review_state: str
    prompt: dict
    options: dict
    correct_index: int
    source: str | None