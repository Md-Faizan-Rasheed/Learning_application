"""Daily quest definitions. Pure data — no I/O. Each day a fixed set of quests
is offered to every player; progress is tracked per user per day.

A quest 'key' is stable so progress rows can be matched to a definition. To
change the daily set, edit DAILY_QUESTS. Keep it small (2-3) so it feels
achievable, not like a chore."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class QuestDef:
    key: str
    description: str
    target: int
    reward_xp: int
    # which progress event advances this quest (see events below)
    event: str


# Progress event types emitted by gameplay.
EVENT_MATCH_PLAYED = "match_played"      # +1 per finished match
EVENT_CORRECT_ANSWER = "correct_answer"  # +1 per correct answer
EVENT_MATCH_WON = "match_won"            # +1 per 1st-place finish


# Today's quest set (same for everyone; progress is per-user).
DAILY_QUESTS: list[QuestDef] = [
    QuestDef(
        key="play_3_matches",
        description="Play 3 matches",
        target=3,
        reward_xp=30,
        event=EVENT_MATCH_PLAYED,
    ),
    QuestDef(
        key="answer_10_correct",
        description="Answer 10 questions correctly",
        target=10,
        reward_xp=40,
        event=EVENT_CORRECT_ANSWER,
    ),
    QuestDef(
        key="win_1_match",
        description="Win a match",
        target=1,
        reward_xp=25,
        event=EVENT_MATCH_WON,
    ),
]


def quests_for_event(event: str) -> list[QuestDef]:
    """The quest definitions advanced by a given progress event."""
    return [q for q in DAILY_QUESTS if q.event == event]