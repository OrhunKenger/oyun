from pydantic import BaseModel
from enum import Enum


class BattleStatus(str, Enum):
    active = "active"
    attacker_won = "attacker_won"
    defender_won = "defender_won"


class StartBattleRequest(BaseModel):
    pixel_x: int
    pixel_y: int


class StartBattleResponse(BaseModel):
    battle_id: str
    pixel_x: int
    pixel_y: int
    duration_seconds: int
    defender_id: str | None


class BattleTapRequest(BaseModel):
    battle_id: str
    tap_count: int = 1


class BattleTapResponse(BaseModel):
    battle_id: str
    attacker_taps: int
    defender_taps: int
    status: BattleStatus


class DamageBreakdown(BaseModel):
    total_damage: float
    damage_ratio: float
    resources_lost: float
    soldiers_lost: int
    building_degraded: str | None  # Hasar alan bina tipi
    pixels_transferred: int
    defender_eliminated: bool  # Tamamen sıfırlandı mı?


class BattleResult(BaseModel):
    battle_id: str
    winner_id: str | None
    attacker_taps: int
    defender_taps: int
    pixel_captured: bool
    status: BattleStatus
    damage: DamageBreakdown | None = None
