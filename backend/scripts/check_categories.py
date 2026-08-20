import asyncio
from app.db import SessionLocal, engine
from sqlalchemy import text


async def main():
    async with SessionLocal() as db:
        print("=== live questions per category ===")
        rows = (await db.execute(text(
            "SELECT c.slug, count(*) AS n "
            "FROM questions q JOIN categories c ON c.id = q.category_id "
            "WHERE q.review_state = 'live' GROUP BY c.slug ORDER BY c.slug"
        ))).all()
        for slug, n in rows:
            print(f"  {slug!r}: {n}")

        print("\n=== all categories (slug, is_active) ===")
        cats = (await db.execute(text(
            "SELECT slug, is_active FROM categories ORDER BY slug"
        ))).all()
        for slug, active in cats:
            print(f"  {slug!r}  active={active}")

        print("\n=== sample: 5 live questions with their category ===")
        sample = (await db.execute(text(
            "SELECT c.slug, q.prompt->>'en' AS q "
            "FROM questions q JOIN categories c ON c.id = q.category_id "
            "WHERE q.review_state = 'live' ORDER BY c.slug LIMIT 12"
        ))).all()
        for slug, q in sample:
            print(f"  [{slug}] {q[:55]}")
    await engine.dispose()


asyncio.run(main())