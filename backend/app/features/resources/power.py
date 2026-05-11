import math
from app.features.resources.model import (
    PlayerResource, Building, PlayerSoldier,
    BUILDING_DEF_WEIGHT, SOLDIER_ATTACK,
)


def calc_power(
    resources: list[PlayerResource],
    buildings: list[Building],
    soldiers: list[PlayerSoldier],
) -> float:
    # Kaynak skoru
    total_res = sum(r.amount for r in resources)
    resources_score = math.log10(total_res + 1) * 100

    # Bina skoru
    buildings_score = sum(
        b.level * BUILDING_DEF_WEIGHT.get(b.building_type, 1)
        for b in buildings
    )

    # Asker skoru
    soldiers_score = sum(
        s.count * SOLDIER_ATTACK.get(s.soldier_type, 0)
        for s in soldiers
    )

    power = (
        resources_score * 0.20
        + buildings_score * 0.30
        + soldiers_score * 0.50
    )
    return round(power, 2)


def calc_territory_radius(power: float) -> int:
    return max(1, min(30, int(math.sqrt(power / 50))))


def calc_attacker_power(soldiers: list[PlayerSoldier], tap_power: int) -> float:
    soldier_atk = sum(
        s.count * SOLDIER_ATTACK.get(s.soldier_type, 0)
        for s in soldiers
    )
    tap_bonus = 1 + (tap_power - 1) * 0.1
    return max(1.0, soldier_atk * tap_bonus)


def calc_defender_power(buildings: list[Building], soldiers: list[PlayerSoldier]) -> float:
    from app.features.resources.model import SOLDIER_DEFENSE
    walls = next((b for b in buildings if b.building_type == "walls"), None)
    wall_bonus = (walls.level * 25) if walls else 0

    building_def = sum(
        b.level * BUILDING_DEF_WEIGHT.get(b.building_type, 1)
        for b in buildings
    )
    soldier_def = sum(
        s.count * SOLDIER_DEFENSE.get(s.soldier_type, 0)
        for s in soldiers
    )
    return max(1.0, wall_bonus + building_def + soldier_def)
