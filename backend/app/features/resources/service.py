import math
from fastapi import HTTPException, status

from app.features.resources.model import (
    ResourceType, SoldierType, Building,
    BUILDING_BASE_COSTS, BUILDING_PRODUCES,
    SOLDIER_TRAIN_COSTS, SOLDIER_REQUIRED_BUILDING,
    SOLDIER_ATTACK, SOLDIER_DEFENSE,
    FOOD_DRAIN_PER_SOLDIER,
)
from app.features.resources.repository import ResourceRepository
from app.features.resources.schemas import (
    TapRequest, TapResponse, AllResourcesResponse, ResourceState,
    UpgradeTapRequest, UpgradeTapResponse,
    BuildRequest, BuildResponse, GetBuildingsResponse, BuildingInfo,
    TrainRequest, TrainResponse, GetSoldiersResponse, SoldierInfo,
)
from app.features.resources.power import calc_power

TAP_POWER_MULTIPLIER = 2.0
AUTO_RATE_PER_LEVEL = 0.5
VALID_BUILDINGS = set(BUILDING_BASE_COSTS.keys())


def tap_upgrade_cost(current_level: int) -> float:
    return 100 * (3 ** current_level)


def building_cost(building_type: str, target_level: int) -> dict[str, float]:
    base = BUILDING_BASE_COSTS[building_type]
    multiplier = 2 ** (target_level - 1)
    return {rtype: amount * multiplier for rtype, amount in base.items()}


class ResourceService:
    def __init__(self, repo: ResourceRepository):
        self.repo = repo

    # ── Kaynaklar ────────────────────────────────────────────

    async def tap(self, user_id: str, data: TapRequest) -> TapResponse:
        resource = await self.repo.get_resource(user_id, data.resource_type)
        if not resource:
            resources = await self.repo.init_player_resources(user_id)
            resource = next(r for r in resources if r.resource_type == data.resource_type)

        gained = resource.tap_power * data.tap_count
        resource.amount += gained
        await self.repo.update_resource(resource)

        return TapResponse(
            resource_type=data.resource_type,
            gained=gained,
            total=resource.amount,
            tap_power=resource.tap_power,
        )

    async def get_all(self, user_id: str) -> AllResourcesResponse:
        resources = await self.repo.get_all_resources(user_id)
        if not resources:
            resources = await self.repo.init_player_resources(user_id)

        resource_map = {r.resource_type: r for r in resources}

        # Eksik kaynak tiplerini ekle (food yoksa oluştur)
        for rtype in ResourceType:
            if rtype not in resource_map:
                from app.features.resources.model import PlayerResource
                r = PlayerResource(user_id=user_id, resource_type=rtype)
                self.repo.db.add(r)
                resource_map[rtype] = r
        await self.repo.db.flush()

        def state(rtype: ResourceType) -> ResourceState:
            r = resource_map.get(rtype)
            return ResourceState(
                resource_type=rtype,
                amount=r.amount if r else 0,
                tap_power=r.tap_power if r else 1,
                tap_power_level=r.tap_power_level if r else 1,
                auto_rate=r.auto_rate if r else 0,
                auto_level=r.auto_level if r else 0,
            )

        return AllResourcesResponse(
            gold=state(ResourceType.gold),
            wood=state(ResourceType.wood),
            stone=state(ResourceType.stone),
            iron=state(ResourceType.iron),
            food=state(ResourceType.food),
        )

    async def upgrade_tap(self, user_id: str, data: UpgradeTapRequest) -> UpgradeTapResponse:
        resource = await self.repo.get_resource(user_id, data.resource_type)
        if not resource:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Kaynak bulunamadı")

        gold = await self.repo.get_resource(user_id, ResourceType.gold)
        if not gold:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "Yeterli altın yok")

        cost = tap_upgrade_cost(resource.tap_power_level)
        if gold.amount < cost:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, f"Yeterli altın yok. Gerekli: {cost}")

        gold.amount -= cost
        resource.tap_power_level += 1
        resource.tap_power = int(TAP_POWER_MULTIPLIER ** (resource.tap_power_level - 1))

        await self.repo.update_resource(resource)
        await self.repo.update_resource(gold)

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

        building = await self.repo.get_building(user_id, data.building_type)
        target_level = (building.level + 1) if building else 1

        costs = building_cost(data.building_type, target_level)
        resources = await self.repo.get_all_resources(user_id)
        resource_map = {r.resource_type: r for r in resources}

        for rtype_str, amount in costs.items():
            rtype = ResourceType(rtype_str)
            r = resource_map.get(rtype)
            if not r or r.amount < amount:
                raise HTTPException(
                    status.HTTP_400_BAD_REQUEST,
                    f"Yetersiz {rtype_str}. Gerekli: {amount}",
                )

        for rtype_str, amount in costs.items():
            resource_map[ResourceType(rtype_str)].amount -= amount
            await self.repo.update_resource(resource_map[ResourceType(rtype_str)])

        produces = BUILDING_PRODUCES.get(data.building_type)
        new_rate = AUTO_RATE_PER_LEVEL * target_level if produces else 0.0
        from app.features.resources.model import BUILDING_DEF_WEIGHT
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
        else:
            building.level = target_level
            building.production_rate = new_rate
            building.defense_contribution = def_contrib
            await self.repo.update_building(building)

        if produces:
            rtype = ResourceType(produces)
            res = resource_map.get(rtype)
            if res:
                res.auto_rate = new_rate
                res.auto_level = target_level
                await self.repo.update_resource(res)

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

        # Gerekli bina var mı?
        required_building = SOLDIER_REQUIRED_BUILDING[stype]
        building = await self.repo.get_building(user_id, required_building)
        if not building:
            raise HTTPException(
                status.HTTP_400_BAD_REQUEST,
                f"{required_building} binası gerekli",
            )

        # Kaynak kontrolü
        costs_per_unit = SOLDIER_TRAIN_COSTS[stype]
        total_costs = {k: v * amount for k, v in costs_per_unit.items()}

        resources = await self.repo.get_all_resources(user_id)
        resource_map = {r.resource_type: r for r in resources}

        for rtype_str, amount_needed in total_costs.items():
            rtype = ResourceType(rtype_str)
            r = resource_map.get(rtype)
            if not r or r.amount < amount_needed:
                raise HTTPException(
                    status.HTTP_400_BAD_REQUEST,
                    f"Yetersiz {rtype_str}. Gerekli: {amount_needed}",
                )

        for rtype_str, amount_needed in total_costs.items():
            resource_map[ResourceType(rtype_str)].amount -= amount_needed
            await self.repo.update_resource(resource_map[ResourceType(rtype_str)])

        soldier = await self.repo.upsert_soldier(user_id, stype, amount)

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
