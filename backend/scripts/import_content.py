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

# Ensure we can import the app package when run as a module or a file.
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.content.schemas import CategoryCreate, QuestionCreate  # noqa: E402
from app.db import SessionLocal  # noqa: E402
from app.content import repository as repo  # noqa: E402


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

        for i, raw in enumerate(questions):
            slug = raw.get("category_slug")
            cat_id = slug_to_id.get(slug)
            if not cat_id:
                report.errors.append(f"question #{i}: unknown category_slug '{slug}'")
                continue
            # Build the same model the API uses (full validation).
            try:
                q = QuestionCreate(
                    category_id=cat_id,
                    difficulty=raw["difficulty"],
                    prompt=raw["prompt"],
                    options=raw["options"],
                    correct_index=raw["correct_index"],
                    source=raw.get("source"),
                )
            except (ValidationError, KeyError) as e:
                msg = e.errors()[0]["msg"] if isinstance(e, ValidationError) else f"missing field {e}"
                report.errors.append(f"question #{i}: {msg}")
                continue

            if dry_run:
                report.questions_created += 1  # would-create
                continue

            created = await repo.create_question(db, q)
            report.questions_created += 1
            if live:
                await repo.set_review_state(db, created["id"], "live")
                report.questions_promoted += 1

        if dry_run:
            await db.rollback()
            print("  (dry-run: no changes committed)")
        else:
            await db.commit()

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