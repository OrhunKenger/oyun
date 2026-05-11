import math
from datetime import datetime, timezone
from fastapi import HTTPException, status

from app.features.resources.model import (
    ResourceType, SoldierType, Building, PlayerResource, PlayerSoldier,
    BUILDING_BASE_COSTS, BUILDING_PRODUCES, BUILDING_DEF_WEIGHT,
    SOLDIER_TRAIN_COSTS, SOLDIER_REQUIRED_BUILDING,
    SOLDIER_ATTACK, SOLDIER_DEFENSE,
    FOOD_DRAIN_PER_TYPE,
    RESOURCE_PRODUCER, OFFLINE_CAP_SECONDS,
    STORAGE_BASE, STORAGE_PER_LEVEL,
    DESERTION_CYCLE_SECONDS, DESERTION_RATE,
)
from app.features.resources.repository import ResourceRepository
from app.features.resources.schemas import (
    TapRequest, TapResponse, AllResourcesResponse, ResourceState,
    UpgradeTapRequest, UpgradeTapResponse,
    BuildRequest, BuildResponse, GetBuildingsResponse, BuildingInfo,
    TrainRequest, TrainResponse, GetSoldiersResponse, SoldierInfo,
)

VALID_BUILDINGS = set(BUILDING_BASE_COSTS.keys())
# Firar sırası: en pahalıdan en ucuza
DESERTION_ORDER = [SoldierType.catapult, SoldierType.knight, SoldierType.archer, SoldierType.swordsman]


# ── Formüller ───────────────────────────────────────────────

def calc_tap_power(level: int) -> int:
    """Üçgensel: 1, 2, 4, 7, 11, 16, 22..."""
    return 1 + (level - 1) * level // 2


def tap_upgrade_cost(current_level: int) -> float:
    """İlk 3 seviye bedava (lvl 1→2, 2→3 free), sonra 50 * target_lvl^2.2."""
    target = current_level + 1
    if target <= 3:
        return 0.0
    return round(50 * (target ** 2.2), 2)


def building_cost(building_type: str, target_level: int) -> dict[str, float]:
    """base * target_level^1.8."""
    base = BUILDING_BASE_COSTS[building_type]
    multiplier = target_level ** 1.8
    return {rtype: round(amount * multiplier, 2) for rtype, amount in base.items()}


def calc_auto_rate(level: int) -> float:
    """0.5 * level^1.5."""
    if level <= 0:
        return 0.0
    return round(0.5 * (level ** 1.5), 3)


def storage_cap_for(rtype: ResourceType, buildings: list[Building]) -> float:
    """Üretici bina seviyesine göre depo kapasitesi."""
    btype = RESOURCE_PRODUCER.get(rtype.value if isinstance(rtype, ResourceType) else rtype)
    b = next((b for b in buildings if b.building_type == btype), None) if btype else None
    level = b.level if b else 0
    return STORAGE_BASE + STORAGE_PER_LEVEL * level


# ── Lazy production: offline kazanç + firar ─────────────────

def _now() -> datetime:
    return datetime.now(timezone.utc)


def _elapsed_seconds(updated_at: datetime | None, now: datetime) -> float:
    if updated_at is None:
        return 0.0
    if updated_at.tzinfo is None:
        updated_at = updated_at.replace(tzinfo=timezone.utc)
    delta = (now - updated_at).total_seconds()
    return max(0.0, min(OFFLINE_CAP_SECONDS, delta))


def _apply_lazy_production(
    resource_map: dict[ResourceType, PlayerResource],
    soldiers: list[PlayerSoldier],
    buildings: list[Building],
) -> tuple[dict[str, float], float, dict[str, int]]:
    """
    Her kaynak için son temas zamanı→şimdi arası üretimi ekler (cap'leyerek).
    Food için askerlerin tüketimi ve firar uygulanır.
    Tap power'ı seviyeden yeniden hesaplar (eski oyuncuları yeni formüle taşır).
    Return: (offline_gains, max_elapsed_seconds, desertions)
    """
    now = _now()
    gains: dict[str, float] = {rt.value: 0.0 for rt in ResourceType}
    desertions: dict[str, int] = {}
    max_elapsed = 0.0

    # Toplam food drain
    soldier_drain = sum(
        s.count * FOOD_DRAIN_PER_TYPE.get(
            s.soldier_type.value if isinstance(s.soldier_type, SoldierType) else s.soldier_type, 0.0
        )
        for s in soldiers
    )

    # Önce food dışındaki kaynakları işle
    for rtype, r in resource_map.items():
        # Tap power formülünü hizala (eski oyuncu migration)
        new_tp = calc_tap_power(r.tap_power_level or 1)
        if r.tap_power != new_tp:
            r.tap_power = new_tp

        if rtype == ResourceType.food:
            continue

        elapsed = _elapsed_seconds(r.updated_at, now)
        max_elapsed = max(max_elapsed, elapsed)
        if elapsed <= 0 or r.auto_rate <= 0:
            continue

        cap = storage_cap_for(rtype, buildings)
        gain_raw = r.auto_rate * elapsed
        new_amount = min(cap, r.amount + gain_raw)
        actual_gain = new_amount - r.amount
        if actual_gain > 0:
            r.amount = new_amount
            gains[rtype.value] = round(actual_gain, 2)

    # Food: üretim + tüketim + firar
    food = resource_map.get(ResourceType.food)
    if food is not None:
        elapsed = _elapsed_seconds(food.updated_at, now)
        max_elapsed = max(max_elapsed, elapsed)
        if elapsed > 0:
            cap = storage_cap_for(ResourceType.food, buildings)
            production = food.auto_rate * elapsed
            consumption = soldier_drain * elapsed
            net = production - consumption

            starting = food.amount
            new_amount = max(0.0, min(cap, food.amount + net))
            food.amount = new_amount
            gains["food"] = round(new_amount - starting, 2)

            # Firar: food yetersiz kaldığı süre
            if soldier_drain > 0 and consumption > (starting + production):
                # Mevcut+üretim ne kadar süreyi karşılar?
                covered_seconds = (starting + production) / soldier_drain
                starving_seconds = max(0.0, elapsed - covered_seconds)
                cycles = int(starving_seconds // DESERTION_CYCLE_SECONDS)
                if cycles > 0:
                    desertions = _apply_desertion(soldiers, cycles)

    return gains, max_elapsed, desertions


def _apply_desertion(soldiers: list[PlayerSoldier], cycles: int) -> dict[str, int]:
    """En pahalıdan başlayarak her döngüde %5 firar."""
    soldier_map = {s.soldier_type: s for s in soldiers}
    result: dict[str, int] = {}
    for stype in DESERTION_ORDER:
        s = soldier_map.get(stype)
        if not s or s.count <= 0:
            continue
        for _ in range(cycles):
            loss = max(1, int(s.count * DESERTION_RATE))
            new_count = max(0, s.count - loss)
            actually_lost = s.count - new_count
            s.count = new_count
            key = stype.value if isinstance(stype, SoldierType) else stype
            result[key] = result.get(key, 0) + actually_lost
            if s.count == 0:
                break
    return result


def _recompute_auto_rates(
    resource_map: dict[ResourceType, PlayerResource],
    buildings: list[Building],
) -> None:
    """Üretici bina seviyesinden auto_rate'i yeniden hesaplayıp eşitler."""
    by_type = {b.building_type: b for b in buildings}
    for rtype, r in resource_map.items():
        btype = RESOURCE_PRODUCER.get(rtype.value)
        b = by_type.get(btype) if btype else None
        level = b.level if b else 0
        new_rate = calc_auto_rate(level)
        if abs(r.auto_rate - new_rate) > 1e-6 or r.auto_level != level:
            r.auto_rate = new_rate
            r.auto_level = level


def _state(rtype: ResourceType, r: PlayerResource, buildings: list[Building]) -> ResourceState:
    cap = storage_cap_for(rtype, buildings)
    return ResourceState(
        resource_type=rtype,
        amount=r.amount,
        tap_power=r.tap_power,
        tap_power_level=r.tap_power_level,
        auto_rate=r.auto_rate,
        auto_level=r.auto_level,
        storage_cap=cap,
        is_capped=r.amount >= cap - 1e-3,
    )


# ── Service ─────────────────────────────────────────────────

class ResourceService:
    def __init__(self, repo: ResourceRepository):
        self.repo = repo

    async def _load_state(self, user_id: str) -> tuple[
        dict[ResourceType, PlayerResource], list[Building], list[PlayerSoldier]
    ]:
        resources = await self.repo.get_all_resources(user_id)
        if not resources:
            resources = await self.repo.init_player_resources(user_id)
        resource_map = {r.resource_type: r for r in resources}
        # Eksik kaynak tipi oluştur (food eksikse vs.)
        for rtype in ResourceType:
            if rtype not in resource_map:
                r = PlayerResource(user_id=user_id, resource_type=rtype)
                self.repo.db.add(r)
                resource_map[rtype] = r
        await self.repo.db.flush()

        buildings = await self.repo.get_buildings(user_id)
        soldiers = await self.repo.get_all_soldiers(user_id)
        return resource_map, buildings, soldiers

    # ── Kaynaklar ────────────────────────────────────────────

    async def tap(self, user_id: str, data: TapRequest) -> TapResponse:
        resource_map, buildings, soldiers = await self._load_state(user_id)
        _apply_lazy_production(resource_map, soldiers, buildings)
        _recompute_auto_rates(resource_map, buildings)

        resource = resource_map[data.resource_type]
        cap = storage_cap_for(data.resource_type, buildings)
        gained_raw = resource.tap_power * data.tap_count
        new_amount = min(cap, resource.amount + gained_raw)
        actual_gained = new_amount - resource.amount
        resource.amount = new_amount

        await self.repo.update_resource(resource)
        await self.repo.db.flush()

        return TapResponse(
            resource_type=data.resource_type,
            gained=actual_gained,
            total=resource.amount,
            tap_power=resource.tap_power,
        )

    async def get_all(self, user_id: str) -> AllResourcesResponse:
        resource_map, buildings, soldiers = await self._load_state(user_id)
        gains, elapsed, desertions = _apply_lazy_production(resource_map, soldiers, buildings)
        _recompute_auto_rates(resource_map, buildings)

        for r in resource_map.values():
            await self.repo.update_resource(r)
        await self.repo.db.flush()

        return AllResourcesResponse(
            gold=_state(ResourceType.gold, resource_map[ResourceType.gold], buildings),
            wood=_state(ResourceType.wood, resource_map[ResourceType.wood], buildings),
            stone=_state(ResourceType.stone, resource_map[ResourceType.stone], buildings),
            iron=_state(ResourceType.iron, resource_map[ResourceType.iron], buildings),
            food=_state(ResourceType.food, resource_map[ResourceType.food], buildings),
            offline_gains=gains,
            offline_seconds=round(elapsed, 1),
            desertions=desertions,
        )

    async def upgrade_tap(self, user_id: str, data: UpgradeTapRequest) -> UpgradeTapResponse:
        resource_map, buildings, soldiers = await self._load_state(user_id)
        _apply_lazy_production(resource_map, soldiers, buildings)
        _recompute_auto_rates(resource_map, buildings)

        resource = resource_map[data.resource_type]
        gold = resource_map[ResourceType.gold]

        cost = tap_upgrade_cost(resource.tap_power_level)
        if cost > 0 and gold.amount < cost:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, f"Yeterli altın yok. Gerekli: {int(cost)}")

        gold.amount -= cost
        resource.tap_power_level += 1
        resource.tap_power = calc_tap_power(resource.tap_power_level)

        await self.repo.update_resource(resource)
        await self.repo.update_resource(gold)
        await self.repo.db.flush()

        return UpgradeTapResponse(
            resource_type=data.resource_type,
            new_tap_power=resource.tap_power,
            new_level=resource.tap_power_level,
            cost={"gold": cost},
        )

    # ── Binalar ──────────────────────────────────────────────

    async def get_buildings(self, user_id: str) -> GetBuildingsResponse:
        buildings = await self.repo.get_buildings(user_id)
        return GetBuildingsResponse(
            buildings=[_building_info(b) for b in buildings]
        )

    async def build_or_upgrade(self, user_id: str, data: BuildRequest) -> BuildResponse:
        if data.building_type not in VALID_BUILDINGS:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "Geçersiz bina tipi")

        resource_map, buildings, soldiers = await self._load_state(user_id)
        _apply_lazy_production(resource_map, soldiers, buildings)

        building = next((b for b in buildings if b.building_type == data.building_type), None)
        target_level = (building.level + 1) if building else 1

        costs = building_cost(data.building_type, target_level)

        for rtype_str, amount in costs.items():
            rtype = ResourceType(rtype_str)
            r = resource_map.get(rtype)
            if not r or r.amount < amount:
                raise HTTPException(
                    status.HTTP_400_BAD_REQUEST,
                    f"Yetersiz {rtype_str}. Gerekli: {int(amount)}",
                )

        for rtype_str, amount in costs.items():
            resource_map[ResourceType(rtype_str)].amount -= amount

        produces = BUILDING_PRODUCES.get(data.building_type)
        new_rate = calc_auto_rate(target_level) if produces else 0.0
        def_contrib = target_level * BUILDING_DEF_WEIGHT.get(data.building_type, 1)

        if building is None:
            building = Building(
                user_id=user_id,
                building_type=data.building_type,
                level=1,
                resource_type=produces,
                production_rate=new_rate,
                defense_contribution=def_contrib,
            )
            await self.repo.create_building(building)
            buildings.append(building)
        else:
            building.level = target_level
            building.production_rate = new_rate
            building.defense_contribution = def_contrib
            await self.repo.update_building(building)

        # Yeni bina seviyesi → tüm üretim oranları ve cap'ler güncellenir
        _recompute_auto_rates(resource_map, buildings)
        for r in resource_map.values():
            await self.repo.update_resource(r)
        await self.repo.db.flush()

        return BuildResponse(
            building=_building_info(building),
            costs_paid={k: v for k, v in costs.items()},
            new_auto_rate=new_rate,
        )

    # ── Askerler ─────────────────────────────────────────────

    async def get_soldiers(self, user_id: str) -> GetSoldiersResponse:
        soldiers = await self.repo.get_all_soldiers(user_id)
        soldier_map = {s.soldier_type: s.count for s in soldiers}

        infos = []
        for stype in SoldierType:
            count = soldier_map.get(stype, 0)
            infos.append(SoldierInfo(
                soldier_type=stype,
                count=count,
                attack_power=SOLDIER_ATTACK[stype],
                defense_power=SOLDIER_DEFENSE[stype],
                train_cost=SOLDIER_TRAIN_COSTS[stype],
            ))

        total_attack = sum(
            soldier_map.get(stype, 0) * SOLDIER_ATTACK[stype] for stype in SoldierType
        )
        total_defense = sum(
            soldier_map.get(stype, 0) * SOLDIER_DEFENSE[stype] for stype in SoldierType
        )

        return GetSoldiersResponse(
            soldiers=infos,
            total_attack=total_attack,
            total_defense=total_defense,
        )

    async def train_soldiers(self, user_id: str, data: TrainRequest) -> TrainResponse:
        stype = data.soldier_type
        amount = data.amount

        if amount < 1:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "En az 1 asker eğit")

        resource_map, buildings, soldiers = await self._load_state(user_id)
        _apply_lazy_production(resource_map, soldiers, buildings)
        _recompute_auto_rates(resource_map, buildings)

        required_building = SOLDIER_REQUIRED_BUILDING[stype]
        building = next((b for b in buildings if b.building_type == required_building), None)
        if not building:
            raise HTTPException(
                status.HTTP_400_BAD_REQUEST,
                f"{required_building} binası gerekli",
            )

        costs_per_unit = SOLDIER_TRAIN_COSTS[stype]
        total_costs = {k: v * amount for k, v in costs_per_unit.items()}

        for rtype_str, amount_needed in total_costs.items():
            rtype = ResourceType(rtype_str)
            r = resource_map.get(rtype)
            if not r or r.amount < amount_needed:
                raise HTTPException(
                    status.HTTP_400_BAD_REQUEST,
                    f"Yetersiz {rtype_str}. Gerekli: {int(amount_needed)}",
                )

        for rtype_str, amount_needed in total_costs.items():
            resource_map[ResourceType(rtype_str)].amount -= amount_needed
            await self.repo.update_resource(resource_map[ResourceType(rtype_str)])

        soldier = await self.repo.upsert_soldier(user_id, stype, amount)
        await self.repo.db.flush()

        return TrainResponse(
            soldier_type=stype,
            new_count=soldier.count,
            costs_paid=total_costs,
        )


def _building_info(b: Building) -> BuildingInfo:
    return BuildingInfo(
        building_type=b.building_type,
        level=b.level,
        resource_type=b.resource_type,
        production_rate=b.production_rate,
        defense_contribution=b.defense_contribution,
    )
