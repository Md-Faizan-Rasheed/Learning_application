import asyncio
from app.db import SessionLocal, engine
from sqlalchemy import text

async def main():
    async with SessionLocal() as db:
        # find likely test junk: Sample/Q? prompts or null source
        rows = (await db.execute(text(
            "SELECT count(*) FROM questions "
            "WHERE prompt->>'en' LIKE 'Sample%' "
            "   OR prompt->>'en' IN ('Q?','Q','Good Q?') "
            "   OR prompt->>'en' LIKE 'SEERAH-Q%' "
            "   OR prompt->>'en' LIKE 'ARABIC-Q%'"
        ))).scalar()
        print(f"test questions to delete: {rows}")
        await db.execute(text(
            "DELETE FROM attempts WHERE question_id IN ("
            "  SELECT id FROM questions WHERE prompt->>'en' LIKE 'Sample%' "
            "     OR prompt->>'en' IN ('Q?','Q','Good Q?') "
            "     OR prompt->>'en' LIKE 'SEERAH-Q%' OR prompt->>'en' LIKE 'ARABIC-Q%')"
        ))
        await db.execute(text(
            "DELETE FROM questions WHERE prompt->>'en' LIKE 'Sample%' "
            "   OR prompt->>'en' IN ('Q?','Q','Good Q?') "
            "   OR prompt->>'en' LIKE 'SEERAH-Q%' OR prompt->>'en' LIKE 'ARABIC-Q%'"
        ))
        await db.commit()
        print("cleaned.")
    await engine.dispose()

asyncio.run(main())