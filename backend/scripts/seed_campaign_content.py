"""Load the Seerah master event list into seerah_events + event_framework_tags.

Reuses the same "resolve category by slug" step import_content.py already
does, and the same batch-DB-session-per-file style used across scripts/.

Usage (from the backend/ directory, with your venv active and .env present):

    python -m scripts.seed_campaign_content
    python -m scripts.seed_campaign_content scripts/seerah_events_38.yaml

Re-run safe: every event is upserted on its unique `slug` column
(ON CONFLICT ... DO UPDATE), and every (event, framework) tag row is
upserted on its (event_id, framework) primary key — running this twice
with the same file converges to the same state, it doesn't duplicate rows.

YAML shape (see scripts/seerah_events_38.yaml):
{
  "category_slug": "seerah",
  "events": [
    {"slug", "name", "order_no", "summary"?, "year_hijri"?, "tags"?: {framework: tag_value}}
  ]
}

name/summary in the YAML are plain English strings (this file predates any
Urdu/Arabic translation pass) — they're stored as {"en": ..., "ur": null,
"ar": null}, matching campaign_stages' own placeholder-null convention from
0015_add_campaign_map for untranslated content, not invented translations.
"""

from __future__ import annotations

import argparse
import asyncio
import sys
from pathlib import Path

import yaml
from sqlalchemy import text

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.db import SessionLocal  # noqa: E402

DEFAULT_YAML_PATH = Path(__file__).resolve().parent / "seerah_events_38.yaml"


def _localized(value: str | None) -> dict:
    """Wrap a plain-English seed string in the {en, ur, ar} shape every other
    JSONB text column in this schema uses (questions.prompt, campaign_stages.name).
    ur/ar are left null — untranslated, not invented — same convention
    0015_add_campaign_map's campaign_stages seed rows already use."""
    return {"en": value, "ur": None, "ar": None} if value is not None else None


class SeedReport:
    def __init__(self) -> None:
        self.events_upserted = 0
        self.tags_upserted = 0
        self.errors: list[str] = []

    def print(self) -> None:
        print("\n=== Seed report ===")
        print(f"Events upserted: {self.events_upserted}")
        print(f"Framework tags upserted: {self.tags_upserted}")
        if self.errors:
            print(f"Errors ({len(self.errors)}):")
            for e in self.errors:
                print(f"  - {e}")
        print("===================\n")


async def _get_category_id(db, category_slug: str) -> str:
    row = (
        await db.execute(
            text("SELECT id FROM categories WHERE slug = :s"),
            {"s": category_slug},
        )
    ).first()
    if not row:
        raise SystemExit(
            f"category '{category_slug}' not found — seed/create it first "
            f"(e.g. via scripts/import_content.py's category step)"
        )
    return str(row[0])


async def _upsert_event(db, *, category_id: str, event: dict) -> str:
    row = (
        await db.execute(
            text(
                """
                INSERT INTO seerah_events (slug, category_id, name, year_hijri, summary)
                VALUES (:slug, :cat, CAST(:name AS jsonb), :year, CAST(:summary AS jsonb))
                ON CONFLICT (slug) DO UPDATE
                SET category_id = EXCLUDED.category_id,
                    name = EXCLUDED.name,
                    year_hijri = EXCLUDED.year_hijri,
                    summary = EXCLUDED.summary
                RETURNING id
                """
            ),
            {
                "slug": event["slug"],
                "cat": category_id,
                "name": _json(_localized(event.get("name"))),
                "year": event.get("year_hijri"),
                "summary": _json(_localized(event.get("summary"))),
            },
        )
    ).first()
    return str(row[0])


async def _upsert_tags(db, *, event_id: str, tags: dict) -> int:
    count = 0
    for framework, tag_value in tags.items():
        await db.execute(
            text(
                """
                INSERT INTO event_framework_tags (event_id, framework, tag_value)
                VALUES (:eid, CAST(:fw AS campaign_framework), :tv)
                ON CONFLICT (event_id, framework) DO UPDATE
                SET tag_value = EXCLUDED.tag_value
                """
            ),
            {"eid": event_id, "fw": framework, "tv": tag_value},
        )
        count += 1
    return count


def _json(value) -> str | None:
    import json

    return json.dumps(value) if value is not None else None


async def seed(yaml_path: Path) -> SeedReport:
    report = SeedReport()
    data = yaml.safe_load(yaml_path.read_text(encoding="utf-8"))
    category_slug = data["category_slug"]
    events = data["events"]

    async with SessionLocal() as db:
        category_id = await _get_category_id(db, category_slug)

        for event in events:
            try:
                event_id = await _upsert_event(db, category_id=category_id, event=event)
                report.events_upserted += 1
                tags = event.get("tags") or {}
                report.tags_upserted += await _upsert_tags(db, event_id=event_id, tags=tags)
            except Exception as e:  # noqa: BLE001
                report.errors.append(f"{event.get('slug', '?')}: {e}")

        await db.commit()

    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "yaml_path",
        nargs="?",
        default=str(DEFAULT_YAML_PATH),
        help="Path to the seerah events YAML file (default: scripts/seerah_events_38.yaml)",
    )
    args = parser.parse_args()

    report = asyncio.run(seed(Path(args.yaml_path)))
    report.print()
    if report.errors:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
