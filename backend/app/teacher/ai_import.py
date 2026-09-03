from __future__ import annotations

from openai import AsyncOpenAI, OpenAIError
from pydantic import BaseModel

from ..config import settings

_SYSTEM_PROMPT = """\
You extract multiple-choice quiz questions from arbitrary pasted text. The \
text may be in any format: a numbered list, "Q:/Answer:" pairs, a table, \
plain prose, or a worksheet with an answer key at the end. Find every \
distinct question in the text.

For each question, produce:
- prompt: the question text, cleaned up (no leading numbering).
- options: 2 to 8 answer choices as plain strings.
- correct_index: the zero-based index of the correct option.
- note: null if the source text explicitly marked the correct answer. If it \
did not, infer the most plausible correct answer and set note to a short \
caution such as "correct answer inferred, please verify".

Skip any part of the text that isn't plausibly a quiz question. If nothing \
in the text is a question, return an empty list."""


class ExtractedQuestion(BaseModel):
    prompt: str
    options: list[str]
    correct_index: int
    note: str | None = None


class _ExtractionResult(BaseModel):
    questions: list[ExtractedQuestion]


async def extract_questions(text: str) -> list[ExtractedQuestion]:
    """Ask the configured OpenAI model to split pasted text into structured
    multiple-choice questions. Raises ValueError on any failure (missing
    key, API error, or an empty/invalid result) — callers turn that into a
    clean 4xx rather than a stack trace."""
    if not settings.openai_api_key:
        raise ValueError("AI import is not configured")

    client = AsyncOpenAI(api_key=settings.openai_api_key)
    try:
        completion = await client.chat.completions.parse(
            model=settings.openai_model,
            messages=[
                {"role": "system", "content": _SYSTEM_PROMPT},
                {"role": "user", "content": text},
            ],
            response_format=_ExtractionResult,
        )
    except OpenAIError as e:
        raise ValueError(f"AI extraction failed: {e}") from e

    result = completion.choices[0].message.parsed
    if result is None or not result.questions:
        raise ValueError("no questions could be extracted from this text")

    for q in result.questions:
        if len(q.options) < 2:
            raise ValueError(f"extracted question has fewer than 2 options: {q.prompt!r}")
        if not (0 <= q.correct_index < len(q.options)):
            raise ValueError(f"extracted question has an out-of-range correct_index: {q.prompt!r}")

    return result.questions
