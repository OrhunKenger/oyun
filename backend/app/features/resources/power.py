import math
from app.features.resources.model import (
    PlayerResource, Building, PlayerSoldier,
    BUILDING_DEF_WEIGHT, SOLDIER_ATTACK, SOLDIER_DEFENSE,
    COUNTER_MATRIX, SoldierType,
)


def _stype(s: PlayerSoldier) -> str:
    return s.soldier_type.value if isinstance(s.soldier_type, SoldierType) else s.soldier_type


def calc_power(
    resources: list[PlayerResource],
    buildings: list[Building],
    soldiers: list[PlayerSoldier],
) -> float:
    total_res = sum(r.amount for r in resources)
    resources_score = math.log10(total_res + 1) * 100

    buildings_score = sum(
        (b.level ** 1.5) * BUILDING_DEF_WEIGHT.get(b.building_type, 1)
        for b in buildings
    )

    soldiers_score = sum(
        s.count * ((SOLDIER_ATTACK.get(_stype(s), 0) + SOLDIER_DEFENSE.get(_stype(s), 0)) / 2)
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


def effective_attack(
    att_soldiers: list[PlayerSoldier],
    def_soldiers: list[PlayerSoldier],
) -> float:
    """Counter matrisi uygulanmış efektif saldırı gücü.

    Her saldıran birim, savunan kompozisyonun fraksiyonu kadar counter çarpanı alır.
    """
    def_total = sum(s.count for s in def_soldiers)
    def_fracs: dict[str, float] = {}
    if def_total > 0:
        for s in def_soldiers:
            if s.count > 0:
                def_fracs[_stype(s)] = def_fracs.get(_stype(s), 0) + s.count / def_total

    total = 0.0
    for a in att_soldiers:
        if a.count <= 0:
            continue
        atype = _stype(a)
        base_atk = SOLDIER_ATTACK.get(atype, 0) * a.count
        if not def_fracs:
            multiplier = 1.0
        else:
            multiplier = sum(
                COUNTER_MATRIX.get(atype, {}).get(dtype, 1.0) * frac
                for dtype, frac in def_fracs.items()
            )
        total += base_atk * multiplier
    return max(1.0, total)


def calc_attacker_power(att_soldiers: list[PlayerSoldier]) -> float:
    """Geriye uyumluluk: sadece toplam saldırı gücü."""
    return max(1.0, sum(s.count * SOLDIER_ATTACK.get(_stype(s), 0) for s in att_soldiers))


def calc_defender_power(buildings: list[Building], soldiers: list[PlayerSoldier]) -> float:
    walls = next((b for b in buildings if b.building_type == "walls"), None)
    # Walls çarpan olur (etkin def *= 1 + 0.08*level)
    wall_mult = 1.0 + 0.08 * (walls.level if walls else 0)

    building_def = sum(
        b.level * BUILDING_DEF_WEIGHT.get(b.building_type, 1)
        for b in buildings
        if b.building_type != "walls"
    )
    soldier_def = sum(
        s.count * SOLDIER_DEFENSE.get(_stype(s), 0)
        for s in soldiers
    )
    return max(1.0, (building_def + soldier_def) * wall_mult)


def carry_capacity(soldiers: list[PlayerSoldier], surviving_pct: float = 1.0) -> float:
    """Asker kompozisyonunun toplam taşıma kapasitesi."""
    from app.features.resources.model import SOLDIER_CARRY
    return sum(
        s.count * surviving_pct * SOLDIER_CARRY.get(_stype(s), 0)
        for s in soldiers
    )


def distribute_losses(
    total_loss_pct: float,
    my_soldiers: list[PlayerSoldier],
    enemy_soldiers: list[PlayerSoldier],
) -> dict[str, int]:
    """Kayıpları counter matrisine göre dağıtır: kötü matchup'taki birim daha çok ölür."""
    enemy_total = sum(s.count for s in enemy_soldiers)
    enemy_fracs: dict[str, float] = {}
    if enemy_total > 0:
        for s in enemy_soldiers:
            if s.count > 0:
                enemy_fracs[_stype(s)] = enemy_fracs.get(_stype(s), 0) + s.count / enemy_total

    # Her benim birim tipim için zafiyet: düşmanın counter[düşman][benim] * frac toplamı
    vuln: dict[str, float] = {}
    for s in my_soldiers:
        if s.count <= 0:
            continue
        my_type = _stype(s)
        v = 0.0
        for enemy_type, frac in enemy_fracs.items():
            v += COUNTER_MATRIX.get(enemy_type, {}).get(my_type, 1.0) * frac
        vuln[my_type] = v if v > 0 else 1.0

    # Ağırlıklı dağılım: count * vuln
    total_weight = sum(s.count * vuln.get(_stype(s), 1.0) for s in my_soldiers)
    my_total = sum(s.count for s in my_soldiers)
    target_total_loss = my_total * total_loss_pct

    losses: dict[str, int] = {}
    for s in my_soldiers:
        if s.count <= 0 or total_weight <= 0:
            continue
        weight = s.count * vuln.get(_stype(s), 1.0)
        share = weight / total_weight
        loss = min(s.count, int(round(share * target_total_loss)))
        losses[_stype(s)] = loss
    return losses
