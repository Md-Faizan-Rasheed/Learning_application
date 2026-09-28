from __future__ import annotations

from typing import Literal
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


class CategoryUpdate(BaseModel):
    display_name: str | None = Field(default=None, min_length=1, max_length=128)
    description: str | None = None
    is_active: bool | None = None


class QuestionCreate(BaseModel):
    category_id: UUID
    difficulty: str
    # language -> text, e.g. {"en": "...", "ur": "...", "ar": "..."}
    prompt: dict[str, str]
    # language -> list of option strings, all lists the same length
    options: dict[str, list[str]]
    correct_index: int = Field(ge=0)
    source: str | None = None
    # Links this question to a Seerah event (seerah_events.id) at creation
    # time — optional, only meaningful for the 'seerah' category. See
    # game/repository.py:pick_live_question's event_framework_tags join.
    event_id: UUID | None = None

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
    event_id: UUID | None = None
    # The campaign stage slug this question's event currently carries a
    # movement_stage tag for, if any — None for untagged/orphaned questions.
    stage_slug: str | None = None


class QuestionListItem(BaseModel):
    id: UUID
    category_id: UUID
    difficulty: str
    review_state: str
    prompt_preview: str
    event_id: UUID | None = None
    # "untagged" | "orphaned" (tagged, but that event has no movement_stage
    # link so campaign mode never serves it) | "linked" (tagged and
    # actually reachable by a campaign stage). See repository._TAG_STATUS_EXPR.
    tag_status: str
    stage_slug: str | None = None
    updated_at: str | None = None


class QuestionUpdate(BaseModel):
    category_id: UUID | None = None
    difficulty: str | None = None
    prompt: dict[str, str] | None = None
    options: dict[str, list[str]] | None = None
    correct_index: int | None = Field(default=None, ge=0)
    source: str | None = None
    # Links this question to a Seerah event (seerah_events.id), which is how
    # campaign mode's per-stage question pool is fed — see
    # game/repository.py:pick_live_question's event_framework_tags join.
    event_id: UUID | None = None

    @field_validator("difficulty")
    @classmethod
    def valid_difficulty(cls, v: str | None) -> str | None:
        if v is not None and v not in DIFFICULTIES:
            raise ValueError(f"difficulty must be one of {DIFFICULTIES}")
        return v

    @field_validator("prompt")
    @classmethod
    def prompt_all_langs(cls, v: dict[str, str] | None) -> dict[str, str] | None:
        if v is None:
            return v
        missing = [lang for lang in SUPPORTED_LANGS if not v.get(lang, "").strip()]
        if missing:
            raise ValueError(f"prompt is missing languages: {missing}")
        return v

    @model_validator(mode="after")
    def options_consistent(self) -> "QuestionUpdate":
        if self.options is None:
            return self
        for lang in SUPPORTED_LANGS:
            if lang not in self.options:
                raise ValueError(f"options is missing language: {lang}")
        lengths = {len(self.options[lang]) for lang in SUPPORTED_LANGS}
        if len(lengths) != 1:
            raise ValueError("every language must list the same number of options")
        n = lengths.pop()
        if n < 2:
            raise ValueError("a question needs at least 2 options")
        if self.correct_index is not None and self.correct_index >= n:
            raise ValueError(f"correct_index {self.correct_index} out of range (0..{n - 1})")
        return self


def _slug_is_clean(v: str) -> str:
    v = v.strip().lower()
    if not v.replace("-", "").replace("_", "").isalnum():
        raise ValueError("slug must be lowercase letters, numbers, hyphens, or underscores")
    return v


def _dict_all_langs(v: dict[str, str], field_name: str) -> dict[str, str]:
    missing = [lang for lang in SUPPORTED_LANGS if not v.get(lang, "").strip()]
    if missing:
        raise ValueError(f"{field_name} is missing languages: {missing}")
    return v


class SeerahEventOut(BaseModel):
    """One row of the 'seerah' category's campaign event list — used to
    populate the event-tagging picker in the admin question editor. Lives
    here (content admin API) rather than the campaign module because it's
    consumed as content-curation data, not campaign gameplay data."""

    id: UUID
    slug: str
    name: dict
    year_hijri: int | None = None
    summary: dict | None = None


class SeerahEventCreate(BaseModel):
    slug: str = Field(min_length=1, max_length=64)
    name: dict[str, str]
    year_hijri: int | None = None
    summary: dict[str, str] | None = None

    @field_validator("slug")
    @classmethod
    def slug_is_clean(cls, v: str) -> str:
        return _slug_is_clean(v)

    @field_validator("name")
    @classmethod
    def name_all_langs(cls, v: dict[str, str]) -> dict[str, str]:
        return _dict_all_langs(v, "name")


class SeerahEventUpdate(BaseModel):
    slug: str | None = Field(default=None, min_length=1, max_length=64)
    name: dict[str, str] | None = None
    year_hijri: int | None = None
    summary: dict[str, str] | None = None

    @field_validator("slug")
    @classmethod
    def slug_is_clean(cls, v: str | None) -> str | None:
        return _slug_is_clean(v) if v is not None else v

    @field_validator("name")
    @classmethod
    def name_all_langs(cls, v: dict[str, str] | None) -> dict[str, str] | None:
        return _dict_all_langs(v, "name") if v is not None else v


class QuestionCountOut(BaseModel):
    count: int


class CampaignStageOption(BaseModel):
    """One campaign stage, for the admin question list's stage-link picker
    and the campaign-content management screen."""

    id: UUID
    slug: str
    name: dict
    description: dict | None = None
    order_no: int


class CampaignStageCreate(BaseModel):
    slug: str = Field(min_length=1, max_length=64)
    name: dict[str, str]
    description: dict[str, str] | None = None

    @field_validator("slug")
    @classmethod
    def slug_is_clean(cls, v: str) -> str:
        return _slug_is_clean(v)

    @field_validator("name")
    @classmethod
    def name_all_langs(cls, v: dict[str, str]) -> dict[str, str]:
        return _dict_all_langs(v, "name")


class CampaignStageUpdate(BaseModel):
    # Renaming the slug also renames every event_framework_tags row already
    # pointing at the old slug, so existing stage links survive — see
    # campaign/repository.py:update_stage.
    slug: str | None = Field(default=None, min_length=1, max_length=64)
    name: dict[str, str] | None = None
    description: dict[str, str] | None = None

    @field_validator("slug")
    @classmethod
    def slug_is_clean(cls, v: str | None) -> str | None:
        return _slug_is_clean(v) if v is not None else v

    @field_validator("name")
    @classmethod
    def name_all_langs(cls, v: dict[str, str] | None) -> dict[str, str] | None:
        return _dict_all_langs(v, "name") if v is not None else v


class StageReorderRequest(BaseModel):
    # The full set of stage ids, in the desired order — must match the
    # existing set exactly (see campaign/repository.py:reorder_stages).
    stage_ids: list[UUID] = Field(min_length=1)


class StageLinkRequest(BaseModel):
    # None clears the event's movement_stage tag (unlink).
    stage_slug: str | None = None


class StageLinkResult(BaseModel):
    event_id: UUID
    stage_slug: str | None


class AdminAiImportRequest(BaseModel):
    category_id: UUID
    text: str = Field(min_length=1, max_length=20000)
    # Optional Seerah event to tag every extracted question with, same as
    # QuestionCreate.event_id — lets an admin AI-import a batch straight
    # into one campaign event instead of tagging each one afterward.
    event_id: UUID | None = None


class AdminAiQuestionOut(BaseModel):
    """One AI-extracted question, already inserted as a 'draft' — same
    shape as QuestionOut plus the extractor's optional confidence note."""

    id: UUID
    category_id: UUID
    difficulty: str
    review_state: str
    prompt: dict
    options: dict
    correct_index: int
    source: str | None = None
    event_id: UUID | None = None
    # Set when the source text didn't explicitly mark the correct answer —
    # the extractor inferred it and flags it for a human check.
    note: str | None = None


class AdminAiImportResult(BaseModel):
    questions: list[AdminAiQuestionOut]


class BulkImportRequest(BaseModel):
    format: Literal["json", "csv"]
    content: str


class BulkImportError(BaseModel):
    row: int
    message: str


class BulkImportResult(BaseModel):
    created: int
    errors: list[BulkImportError]