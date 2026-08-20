"""Remove leftover test/junk questions created during development, keeping the
real imported content. Safe: it only targets questions whose prompt matches the
known test patterns, and removes their attempts first (FK-safe).

Run from backend/ with your venv active and DATABASE_URL set (or .env present):

    python -m scripts.clean_test_questions            # shows what WOULD be deleted
    python -m scripts.clean_test_questions --delete   # actually deletes
"""

from __future__ import annotations

import argparse
import asyncio
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from sqlalchemy import text  # noqa: E402

from app.db import SessionLocal, engine  # noqa: E402

_TEST_PATTERNS = [
    "prompt->>'en' LIKE 'Sample%'",
    "prompt->>'en' LIKE 'SEERAH-Q%'",
    "prompt->>'en' LIKE 'ARABIC-Q%'",
    "prompt->>'en' IN ('Q?', 'Q', 'Good Q?', 'Missing urdu', 'Bad idx')",
]
_WHERE = " OR ".join(_TEST_PATTERNS)


async def run(delete: bool) -> None:
    async with SessionLocal() as db:
        ids = (
            await db.execute(text(f"SELECT id, prompt->>'en' AS q FROM questions WHERE {_WHERE}"))
        ).all()
        print(f"matched {len(ids)} test question(s):")
        for _id, q in ids:
            print(f"  - {q}")

        if not delete:
            print("\n(dry run - nothing deleted. Re-run with --delete to remove.)")
            await engine.dispose()
            return

        await db.execute(text(f"DELETE FROM attempts WHERE question_id IN (SELECT id FROM questions WHERE {_WHERE})"))
        result = await db.execute(text(f"DELETE FROM questions WHERE {_WHERE}"))
        await db.commit()
        print(f"\ndeleted {result.rowcount} question(s). Real content preserved.")
    await engine.dispose()


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--delete", action="store_true", help="actually delete (default is dry run)")
    args = ap.parse_args()

    if not os.getenv("DATABASE_URL"):
        env = Path(__file__).resolve().parents[1] / ".env"
        if env.exists():
            for line in env.read_text().splitlines():
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    os.environ.setdefault(k.strip(), v.strip())

    asyncio.run(run(args.delete))


if __name__ == "__main__":
    main()