from __future__ import annotations

import csv
import io
import json

from pydantic import ValidationError
from sqlalchemy.ext.asyncio import AsyncSession

from . import repository as repo
from .schemas import BulkImportError, BulkImportResult, QuestionCreate

_LANGS = ("en", "ar", "ur")
_MAX_CSV_OPTIONS = 4
_CSV_REQUIRED_COLUMNS = {
    "category_slug",
    "difficulty",
    "prompt_en",
    "prompt_ar",
    "prompt_ur",
    "correct_index",
}


def parse_json_rows(content: str) -> list[dict]:
    """Parse a pasted JSON array of question objects. Raises ValueError on
    malformed input — this fails the whole import, since it means the pasted
    content itself is broken, not one bad row among many good ones."""
    try:
        data = json.loads(content)
    except json.JSONDecodeError as e:
        raise ValueError(f"invalid JSON: {e}") from e
    if not isinstance(data, list):
        raise ValueError("JSON content must be a top-level array of question objects")
    return data


def parse_csv_rows(content: str) -> list[dict]:
    """Parse pasted CSV using the fixed bulk-import template (4 option
    columns per language; blank trailing cells are dropped so 2/3-option
    questions work). Raises ValueError if the header doesn't match — that's
    a template mismatch, not a per-row content problem."""
    reader = csv.DictReader(io.StringIO(content))
    if reader.fieldnames is None:
        raise ValueError("CSV content is empty")
    missing = _CSV_REQUIRED_COLUMNS - set(reader.fieldnames)
    if missing:
        raise ValueError(f"CSV is missing required columns: {sorted(missing)}")

    rows: list[dict] = []
    for raw in reader:
        options: dict[str, list[str]] = {}
        for lang in _LANGS:
            opts = []
            for i in range(1, _MAX_CSV_OPTIONS + 1):
                val = (raw.get(f"option_{lang}_{i}") or "").strip()
                if val:
                    opts.append(val)
            options[lang] = opts
        rows.append(
            {
                "category_slug": (raw.get("category_slug") or "").strip(),
                "difficulty": (raw.get("difficulty") or "").strip(),
                "prompt": {lang: (raw.get(f"prompt_{lang}") or "").strip() for lang in _LANGS},
                "options": options,
                "correct_index": (raw.get("correct_index") or "").strip(),
            }
        )
    return rows


def _format_validation_error(e: ValidationError) -> str:
    parts = []
    for err in e.errors():
        loc = ".".join(str(x) for x in err["loc"])
        parts.append(f"{loc}: {err['msg']}" if loc else err["msg"])
    return "; ".join(parts)


async def import_rows(db: AsyncSession, raw_rows: list[dict]) -> BulkImportResult:
    """Two-phase: validate + resolve categories for every row first (pure
    reads), then insert only the rows that passed — so one bad row can't
    sink the whole batch, and a mid-loop DB failure can't leave a partial
    batch of writes behind."""
    validated: list[QuestionCreate] = []
    errors: list[BulkImportError] = []

    for i, raw in enumerate(raw_rows, start=1):
        try:
            row = dict(raw)
            slug_or_id = row.pop("category_slug", None) or row.get("category_id")
            if not slug_or_id:
                raise ValueError("category_slug (or category_id) is required")
            category = await repo.find_category(db, str(slug_or_id))
            if category is None:
                raise ValueError(f"category '{slug_or_id}' not found")
            row["category_id"] = category["id"]
            if isinstance(row.get("correct_index"), str):
                if not row["correct_index"].strip():
                    raise ValueError("correct_index is required")
                row["correct_index"] = int(row["correct_index"])
            validated.append(QuestionCreate(**row))
        except ValidationError as e:
            errors.append(BulkImportError(row=i, message=_format_validation_error(e)))
        except (ValueError, TypeError) as e:
            errors.append(BulkImportError(row=i, message=str(e)))

    created = 0
    for data in validated:
        await repo.create_question(db, data)
        created += 1

    return BulkImportResult(created=created, errors=errors)
