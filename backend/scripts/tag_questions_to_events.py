"""One-off content pass: assigns questions.event_id on the existing live
'seerah' question bank, so campaign mode (which filters questions via
event_framework_tags -> seerah_events -> questions.event_id, see
app/game/repository.py:pick_live_question) actually has real content to
serve instead of the empty result it gets today.

Matching is a conservative keyword classifier: each seerah_events slug has
a list of phrases drawn directly from the real question prompts. A question
is tagged only when exactly one event's phrase list matches its prompt; zero
or multiple matches are left untagged and reported for manual follow-up via
the admin question-edit API (PATCH /admin/questions/{id} now accepts
event_id, see app/content/schemas.py). Nothing here is a substitute for a
human content pass on the remainder.

Usage:
    python -m scripts.tag_questions_to_events            # dry run, prints a report
    python -m scripts.tag_questions_to_events --apply     # actually writes event_id
"""

from __future__ import annotations

import argparse
import asyncio
import re
import sys
from pathlib import Path

from sqlalchemy import text

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.db import SessionLocal  # noqa: E402

# question_id -> event slug, for the handful of prompts whose text mentions
# a different event by name than the one they're actually about (e.g. a
# "harder than Uhud?" question whose answer is about Ta'if).
OVERRIDES: dict[str, str] = {
    "f04c496e-d825-4db7-ad62-758fe0bbb757": "journey_to_taif",
}

# Ordered: slug -> phrases (lowercase, must appear verbatim as a substring
# of the lowercased English prompt). Phrases are deliberately long/specific
# to avoid one question matching two events.
EVENT_KEYWORDS: dict[str, list[str]] = {
    "arabia_before_islam": [
        "three ancient peoples", "souk ukaz", "already vanished before islam",
        "forbidden for warfare", "tribal chief was typically selected",
        "dhu nuwas", "baby girls sometimes treated",
        "oldest idol worshipped in arabia", "idol placed inside the kaaba held the greatest status",
        "how many idols were kept inside the kaaba before islam",
        "killing or bloodshed permitted within the sanctuary of makkah",
        "why is fighting not permitted within the sanctuary of makkah",
    ],
    "lineage_rebuilding_kabah": [
        "hazrat ibrahim build the kaaba", "first built the kaaba",
        "maqam-e-ibrahim", "prayers of hazrat ibrahim for the people of makkah",
        "descendant of which son of hazrat ibrahim", "ibrahim (as) pass away",
        "what are safa and marwah", "safa and marwah) performed",
    ],
    "year_of_the_elephant": [
        "year of the elephant", "abrahah do to abdul muttalib during the siege",
        "battlements of the persian emperor's palace collapsed",
        "abrahah want to attack the kaaba",
    ],
    "birth_and_early_signs": [
        "time of day was the prophet ",
        "day of the week was the prophet ", "month was the prophet ",
        "which city was the prophet ", "quarter of makkah was the prophet ",
        "fire, kept burning continuously", "idols of the kaaba at the moment the prophet",
        "change came over makkah at the moment", "witness at the exact moment of the birth",
        "physical condition was the prophet", "blessed tongue the moment he entered the world",
        "witness at the moment of the prophet", "aqiqah",
        "informed the prophet's", "grandfather of the birth",
        "how long before the prophet's", "birth did his father, abdullah, pass away",
        "age did the prophet's father, abdullah, pass away",
        "tribe did the prophet's father, abdullah, belong to",
        "after hazrat isa (jesus, as) did the prophet's", "blessed birth take place",
        "later mark his own day of birth", "freed a slave-girl in joy over his birth",
        "gave the prophet ", "the name \"muhammad\"", "the name \"ahmad\"",
        "names \"muhammad\" and \"ahmad\" mean",
    ],
    "infancy_with_halimah": [
        "halimah", "foster brothers", "foster-sister", "foster-mother",
        "shaqq-e-sadr", "shaqq as-sadr", "wet-nurse", "wet nurse",
        "from how many different women did the prophet", "nurse during his infancy",
        "lying in the cradle",
    ],
    "childhood_loss_of_parents": [
        "mother, hazrat aminah, passed away", "mother, hazrat aminah",
        "with his mother when she passed away", "mother, hazrat aminah, buried",
        "back to makkah after his mother's death",
        "after his mother's passing", "grandfather, abdul muttalib, pass away",
        "grandfather, abdul muttalib, passed away",
    ],
    "under_care_of_abu_talib": [
        "took charge of raising the prophet ", "after his grandfather's death",
        "son of abu talib did the prophet ", "personally raise",
        "abu talib's actual", "close friend of the prophet ", "during his childhood",
        "helped him without openly declaring his acceptance of islam",
    ],
    "youth_trading_journeys": [
        "nature of the first journey the prophet ", "made with his uncle",
        "first journey to syria", "profession during his youth",
        "khadijah's trade goods", "invited the prophet ", "conduct trade on her behalf",
        "profit did hazrat khadijah gain from this particular trade",
        "business principle did the prophet ", "trade with hazrat khadijah's goods",
        "send along with the prophet ", "on this trading journey",
        "monk expressed a wish to meet the young prophet ",
        "monk tell abu talib upon seeing the young prophet",
        "foreign trading journeys did the prophet ",
    ],
    "hilf_al_fudul": [
        "hilf al-fudul", "quarrel over during the reconstruction of the kaaba",
        "arbitrator in the dispute over the black stone",
        "resolved the dispute over placing the black stone",
        "dispute over the black stone continue", "black stone (hajar-e-aswad) fixed",
        "architect brought to help rebuild the kaaba",
        "quraysh rebuild the kaaba from scratch",
        "when the quraysh began rebuilding the kaaba",
        "rebuilding of the kaaba and the resolution of the black stone dispute",
        "\"hajar-e-aswad\" mean", "why do muslims kiss the black stone",
        "rebuilt the kaaba the second time", "pact made during the prophet's ",
        "aimed at protecting the wronged",
    ],
    "contemplation_cave_of_hira": [
        "take with him to the cave of hira", "worship and contemplation before prophethood",
        "how far is the cave of hira from makkah", "begin retreating to the cave of hira",
        "do while in the cave of hira",
    ],
    "first_revelation": [
        "first word the angel spoke", "angel who brought the first revelation",
        "verses were revealed in this first revelation",
        "jibra'il repeat his command before the prophet recited",
        "respond to the angel's command", "jibra'il recite the first revealed verses",
        "day of the week did the first revelation descend",
        "emotional state after jibra'il departed following the first revelation",
        "say to hazrat khadijah upon returning home after the first revelation",
        "khadijah comfort the prophet ", "after the first revelation",
        "khadijah take the prophet ", "guidance after the first revelation",
        "waraqah bin naufal tell the prophet ", "literal meaning of \"wahi\"",
        "technical/religious meaning of \"wahi\"", "after the first revelation did the second revelation",
        "see jibra'il during the second revelation",
        "surah's verses descended in the second revelation",
        "when did the prophet say he became a prophet",
    ],
    "secret_dawah": [
        "preach islam secretly", "period of secret preaching",
        "as-sabiqun al-awwalun", "honored with writing down revelation",
        "invite when he first called his kinsmen to the faith",
        "act of worship was the prophet ", "first commanded to perform after revelation began",
    ],
    "public_declaration": [
        "begin his public preaching", "open, public preaching begin",
        "warn your close relatives", "recited the kalimah and the qur'an in front of the quraysh",
    ],
    "persecution_of_early_muslims": [
        "endured the most severe torture in makkah", "shield the prophet ",
        "from harm and hardship in makkah", "taunted by the quraysh for their poverty",
        "mother went on a hunger strike", "punish hazrat uthman",
        "hazrat umar beat", "zubair bin awwam punished him severely",
        "first person martyred for the cause of islam",
        "quraysh turn against the prophet ", "and oppose him",
        "various incentives to abandon his preaching",
        "reject the quraysh's offer to abandon his preaching",
        "greatest opponent among his own family",
        "caused the prophet ", "the most distress in makkah",
    ],
    "migration_to_abyssinia": [
        "abyssinia", "negus",
    ],
    "boycott_of_banu_hashim": [
        "shi'b abi talib", "banu hashim", "document of the boycott pact",
        "pact made by the quraysh against banu hashim",
    ],
    "year_of_sorrow": [
        "aam al-huzn", "age did hazrat khadijah pass away",
        "days apart were the deaths of hazrat khadijah and abu talib",
        "two losses did the prophet suffer during \"aam al-huzn\"",
        "year is referred to as \"aam al-huzn\"", "age did abu talib pass away",
        "month did abu talib pass away",
        "uncle of the prophet passed away three years before the hijrah",
    ],
    "journey_to_taif": [
        "ta'if", "valley of nakhlah",
    ],
    "isra_and_miraj": [
        "mi'raj", "isra", "al-isra", "night journey", "masjid al-aqsa",
        "bayt al-ma'mur", "reduction in the number of daily prayers",
    ],
    "pledges_of_aqabah": [
        "aqabah", "bay'ah al-aqabah",
        "who led the caravan of pilgrims from madinah who accepted islam in the 13th year",
        "six people from madinah who first accepted islam",
    ],
    "hijrah_to_madinah": [
        "cave of thawr", "accompanied the prophet on the night of the hijrah",
        "literal meaning of \"hijrah\"", "leave makkah for the hijrah",
        "night of the week did the prophet ", "instructions did the prophet ",
        "give to hazrat ali before the hijrah", "sleep in his own bed on the night of the hijrah",
        "pursued the prophet ", "hoping to capture him for the reward",
        "reward did the quraysh offer for capturing the prophet",
        "pass by the men the quraysh had set to kill him",
        "provisions upon hearing news of the prophet's ", "intended hijrah",
        "bringing milk to the prophet ", "abu bakr in the cave of thawr",
        "delivered food to the prophet ", "while they were in the cave of thawr",
        "bring news of the quraysh to the prophet ", "hiding in the cave of thawr",
        "and abu bakr remain in the cave of thawr",
        "how far is the cave of thawr from makkah", "entered the cave of thawr first",
        "problem did abu bakr encounter inside the cave",
        "abu bakr siddiq do upon entering the cave",
        "relieve abu bakr's pain in the cave",
        "cave did the prophet ", "abu bakr take shelter during the hijrah",
        "inform abu bakr siddiq of divine permission for the hijrah",
        "what did suraqah do upon witnessing this sign",
        "suraqah bin ju'shum's horse", "hijrah to madinah",
        "in makkah, from birth until the hijrah", "date of the month did the prophet ",
        "migrate from makkah", "traveling party during the journey from makkah to madinah",
        "days did it take the prophet ", "reach quba from makkah",
        "first informed the people of madinah of the prophet's approach",
        "ansar (people of madinah) feel upon learning the prophet ",
        "hoped to host him", "she-camel that he rode into madinah",
        "she-camel finally stop in madinah", "animal was the prophet ",
        "riding when he entered madinah", "reach the outskirts of madinah",
        "visit makkah after the hijrah", "first well-known place the prophet ",
        "reached on his journey to madinah", "stay at quba before entering madinah proper",
        "abu ayyub's house", "muslims who migrated to madinah from makkah known",
        "true \"muhajir\" (migrant)", "first companion to migrate toward madinah",
        "openly and defiantly announced his migration to the quraysh",
    ],
    "mosque_and_brotherhood": [
        "masjid an-nabawi", "muakhat", "doors did the prophet ",
        "set for masjid an-nabawi", "material was used for the roof of masjid an-nabawi",
        "purchase the site for masjid an-nabawi", "companions take part in building masjid an-nabawi",
        "existed on the site of masjid an-nabawi before it was built",
        "other roles did masjid an-nabawi serve", "happen inside masjid an-nabawi during rain",
        "private quarters (hujurat)", "structure did the prophet ", "build at quba",
        "qur'an describe the mosque built at quba",
        "mosques established in and around madinah besides masjid an-nabawi",
    ],
    "constitution_of_madinah": [
        "constitution of madinah", "first constitution of islam",
        "representatives (naqeeb) did the prophet ", "religious freedom did the constitution of madinah",
    ],
    "battle_of_badr": ["battle of badr"],
    "battle_of_uhud": ["battle of uhud", "martyred during his lifetime"],
    "battle_of_the_trench": ["battle of the trench", "khandaq"],
    "treaty_of_hudaybiyyah": ["hudaybiyyah"],
    "battle_of_khaybar": ["battle of khaybar", "khaybar"],
    "letters_to_kings": ["letters to the kings", "letters inviting"],
    "conquest_of_makkah": ["conquest of makkah"],
    "battle_of_hunayn_and_taif": ["battle of hunayn"],
    "expedition_of_tabuk": ["tabuk"],
    "farewell_pilgrimage": ["farewell pilgrimage", "hajjat-ul-wida", "farewell sermon"],
}


class TagReport:
    def __init__(self) -> None:
        self.tagged: list[tuple[str, str]] = []
        self.ambiguous: list[tuple[str, list[str]]] = []
        self.unmatched: list[str] = []

    def print(self, *, applied: bool) -> None:
        print(f"Matched (single event): {len(self.tagged)}")
        print(f"Ambiguous (multiple candidate events, left untagged): {len(self.ambiguous)}")
        print(f"Unmatched (no keyword hit, left untagged): {len(self.unmatched)}")
        if self.ambiguous:
            print("\nAmbiguous question ids and their candidates:")
            for qid, slugs in self.ambiguous:
                print(f"  {qid}: {slugs}")
        print(
            "\n"
            + ("Applied to the database." if applied else "Dry run only — no rows were written. Re-run with --apply to write them.")
        )


def _normalize(prompt_en: str) -> str:
    """Lowercases and strips the ﷺ ligature (U+FDFA) that sits between
    "Prophet" and the next word in most prompts, then collapses the
    resulting double space — so keyword phrases can be written as natural
    contiguous text instead of split around where that symbol falls."""
    text = (prompt_en or "").lower()
    text = text.replace("ﷺ", " ")
    return re.sub(r"\s+", " ", text)


def classify(prompt_en: str, question_id: str) -> list[str]:
    if question_id in OVERRIDES:
        return [OVERRIDES[question_id]]
    lowered = _normalize(prompt_en)
    matches = [slug for slug, phrases in EVENT_KEYWORDS.items() if any(p in lowered for p in phrases)]
    return matches


async def run(apply: bool) -> None:
    report = TagReport()
    async with SessionLocal() as db:
        slug_to_id = {
            row[0]: str(row[1])
            for row in (await db.execute(text("SELECT slug, id FROM seerah_events"))).all()
        }
        rows = (
            await db.execute(
                text(
                    """
                    SELECT q.id, q.prompt->>'en' AS prompt
                    FROM questions q
                    JOIN categories c ON c.id = q.category_id
                    WHERE c.slug = 'seerah' AND q.review_state = 'live' AND q.event_id IS NULL
                    """
                )
            )
        ).all()

        for qid, prompt in rows:
            matches = classify(prompt, str(qid))
            if len(matches) == 1:
                report.tagged.append((str(qid), matches[0]))
            elif len(matches) > 1:
                report.ambiguous.append((str(qid), matches))
            else:
                report.unmatched.append(str(qid))

        if apply:
            for qid, slug in report.tagged:
                await db.execute(
                    text("UPDATE questions SET event_id = :e WHERE id = :q"),
                    {"e": slug_to_id[slug], "q": qid},
                )
            await db.commit()

    report.print(applied=apply)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true", help="write event_id instead of a dry run")
    args = parser.parse_args()
    asyncio.run(run(args.apply))


if __name__ == "__main__":
    main()
