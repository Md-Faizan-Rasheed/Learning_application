"""Bulk-import categories and questions from a JSON file.

Reuses the SAME Pydantic validators as the admin API, so anything this script
accepts is exactly what the API would accept — one source of validation truth.

Usage (from the backend/ directory, with your venv active and .env present):

    python -m scripts.import_content scripts/content_example.json
    python -m scripts.import_content my_seerah_bank.json --live      # auto-promote to live
    python -m scripts.import_content my_bank.json --dry-run          # validate only, no DB writes

JSON shape:
{
  "categories": [ {"slug","display_name","description?"} ],
  "questions":  [ {"category_slug","difficulty","prompt{en,ur,ar}",
                   "options{en,ur,ar}","correct_index","source?"} ]
}

Questions load as 'draft' by default (respecting the scholar-review workflow).
Pass --live to promote them straight to 'live' (use only for pre-reviewed banks).
"""

from __future__ import annotations

import argparse
import asyncio
import json
import os
import sys
from pathlib import Path

from pydantic import ValidationError
from sqlalchemy.exc import DBAPIError

# Ensure we can import the app package when run as a module or a file.
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.content.schemas import CategoryCreate, QuestionCreate  # noqa: E402
from app.db import SessionLocal  # noqa: E402
from app.content import repository as repo  # noqa: E402

# A long-running import over a remote (e.g. Render) connection can hit a
# transient network blip mid-run — importing in small, independently-committed
# batches bounds the damage to one batch instead of the whole file, and
# retrying a batch on a dropped connection recovers from a blip automatically
# instead of losing hours of progress to it.
QUESTIONS_PER_BATCH = 25
MAX_BATCH_RETRIES = 3
RETRY_DELAY_SECONDS = 2


class ImportReport:
    def __init__(self) -> None:
        self.categories_created = 0
        self.categories_existing = 0
        self.questions_created = 0
        self.questions_promoted = 0
        self.errors: list[str] = []

    def print(self) -> None:
        print("\n─── Import report ───")
        print(f"  categories created : {self.categories_created}")
        print(f"  categories existing: {self.categories_existing}")
        print(f"  questions created  : {self.questions_created}")
        print(f"  questions promoted : {self.questions_promoted}")
        if self.errors:
            print(f"  errors ({len(self.errors)}):")
            for e in self.errors:
                print(f"    - {e}")
        else:
            print("  errors: none")
        print("─────────────────────")


async def _resolve_categories(db, cats: list[dict], report: ImportReport) -> dict[str, str]:
    """Ensure every category exists; return slug -> id map."""
    slug_to_id: dict[str, str] = {}
    existing = {c["slug"]: str(c["id"]) for c in await repo.list_categories(db, active_only=False)}
    for raw in cats:
        try:
            data = CategoryCreate(**raw)
        except ValidationError as e:
            report.errors.append(f"category {raw.get('slug','?')}: {e.errors()[0]['msg']}")
            continue
        if data.slug in existing:
            slug_to_id[data.slug] = existing[data.slug]
            report.categories_existing += 1
        else:
            created = await repo.create_category(db, data)
            slug_to_id[data.slug] = str(created["id"])
            report.categories_created += 1
    return slug_to_id


async def _import_batch(
    batch: list[QuestionCreate], *, live: bool, report: ImportReport
) -> None:
    """Insert one batch in its own short transaction, retrying with a fresh
    session on a dropped connection. A retry re-runs the whole batch, which is
    safe: nothing in a failed attempt was ever committed, so there's nothing
    to duplicate."""
    for attempt in range(1, MAX_BATCH_RETRIES + 1):
        created = 0
        promoted = 0
        try:
            async with SessionLocal() as db:
                for q in batch:
                    row = await repo.create_question(db, q)
                    created += 1
                    if live:
                        await repo.set_review_state(db, row["id"], "live")
                        promoted += 1
                await db.commit()
            report.questions_created += created
            report.questions_promoted += promoted
            return
        except DBAPIError as e:
            if attempt == MAX_BATCH_RETRIES:
                report.errors.append(
                    f"batch of {len(batch)} question(s) failed after "
                    f"{MAX_BATCH_RETRIES} attempts (connection kept dropping): {e}"
                )
                return
            print(
                f"  connection dropped mid-batch, retrying "
                f"(attempt {attempt + 1}/{MAX_BATCH_RETRIES})…"
            )
            await asyncio.sleep(RETRY_DELAY_SECONDS * attempt)


async def run(path: str, *, live: bool, dry_run: bool) -> ImportReport:
    report = ImportReport()
    payload = json.loads(Path(path).read_text(encoding="utf-8"))
    cats = payload.get("categories", [])
    questions = payload.get("questions", [])

    async with SessionLocal() as db:
        slug_to_id = await _resolve_categories(db, cats, report)
        # also pick up any categories that already existed but weren't in the file
        for c in await repo.list_categories(db, active_only=False):
            slug_to_id.setdefault(c["slug"], str(c["id"]))
        if dry_run:
            await db.rollback()
        else:
            await db.commit()

    # Validation is pure/local (no DB), so it happens the same way regardless
    # of dry_run or how many questions there are.
    validated: list[QuestionCreate] = []
    for i, raw in enumerate(questions):
        slug = raw.get("category_slug")
        cat_id = slug_to_id.get(slug)
        if not cat_id:
            report.errors.append(f"question #{i}: unknown category_slug '{slug}'")
            continue
        try:
            validated.append(
                QuestionCreate(
                    category_id=cat_id,
                    difficulty=raw["difficulty"],
                    prompt=raw["prompt"],
                    options=raw["options"],
                    correct_index=raw["correct_index"],
                    source=raw.get("source"),
                )
            )
        except (ValidationError, KeyError) as e:
            msg = e.errors()[0]["msg"] if isinstance(e, ValidationError) else f"missing field {e}"
            report.errors.append(f"question #{i}: {msg}")

    if dry_run:
        report.questions_created += len(validated)
        print("  (dry-run: no changes committed)")
        return report

    for start in range(0, len(validated), QUESTIONS_PER_BATCH):
        batch = validated[start : start + QUESTIONS_PER_BATCH]
        await _import_batch(batch, live=live, report=report)
        print(f"  imported {min(start + QUESTIONS_PER_BATCH, len(validated))}/{len(validated)}…")

    return report


def main() -> None:
    ap = argparse.ArgumentParser(description="Bulk-import questions from JSON.")
    ap.add_argument("path", help="path to the content JSON file")
    ap.add_argument("--live", action="store_true", help="promote imported questions to 'live'")
    ap.add_argument("--dry-run", action="store_true", help="validate only; write nothing")
    args = ap.parse_args()

    if not os.getenv("DATABASE_URL"):
        # load .env if present so DATABASE_URL is available
        env = Path(__file__).resolve().parents[1] / ".env"
        if env.exists():
            for line in env.read_text().splitlines():
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    os.environ.setdefault(k.strip(), v.strip())

    report = asyncio.run(run(args.path, live=args.live, dry_run=args.dry_run))
    report.print()
    sys.exit(1 if report.errors else 0)


if __name__ == "__main__":
    main()


    # validate a bank without writing anything
# python -m scripts.import_content scripts/questions.json --dry-run

# # load it, leaving questions as draft (for review)
# python -m scripts.import_content scripts/questions.json

# # load AND promote to live (for already-reviewed banks)
# python -m scripts.import_content scripts/questions.json --live