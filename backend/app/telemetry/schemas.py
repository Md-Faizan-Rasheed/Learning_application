from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel


class TapThroughEventIn(BaseModel):
    section: Literal["journey", "quick_play"]
    card_id: str
    client_timestamp: datetime
