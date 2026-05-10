import math
from fastapi import HTTPException, status

from app.features.resources.model import ResourceType, Building
from app.features.resources.repository import ResourceRepository
from app.features.resources.schemas import (
    TapRequest, TapResponse, AllResourcesResponse, ResourceState,
    UpgradeTapRequest, UpgradeTapResponse,
    BuildRequest, BuildResponse, GetBuildingsResponse, BuildingInfo,
)

TAP_POWER_MULTIPLIER = 2.0

def tap_upgrade_cost(current_level: int) -> float:
    return 100 * (3 ** current_level)

# Kaynak tipi → bina adı
RESOURCE_BUILDINGS = {
    ResourceType.gold: "treasury",
    ResourceType.wood: "sawmill",
    ResourceType.stone: "quarry",
    ResourceType.iron: "forge",
}

# Bina tipi → kaynak tipi
BUILDING_RESOURCE = {v: k for k, v in RESOURCE_BUILDINGS.items()}

# Bina inşa/yükseltme maliyeti: {bina_tipi: {level: {ResourceType: miktar}}}
# Her seviye için: base_cost * (2 ^ (level-1))
BUILDING_BASE_COSTS: dict[str, dict[ResourceType, float]] = {
    "sawmill":  {ResourceType.wood: 50,  ResourceType.stone: 30},
    "quarry":   {ResourceType.wood: 40,  ResourceType.stone: 50},
    "forge":    {ResourceType.stone: 60, ResourceType.iron: 20},
    "treasury": {ResourceType.wood: 50,  ResourceType.gold: 40},
}

VALID_BUILDINGS = set(BUILDING_BASE_COSTS.keys())

# Seviye başına otomatik üretim artışı (kaynak/saniye)
AUTO_RATE_PER_LEVEL = 0.5

def building_cost(building_type: str, target_level: int) -> dict[ResourceType, float]:
    base = BUILDING_BASE_COSTS[building_type]
    multiplier = 2 ** (target_level - 1)
    return {rtype: amount * multiplier for rtype, amount in base.items()}


class ResourceService:
    def __init__(self, repo: ResourceRepository):
        self.repo = repo

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
        )

    async def upgrade_tap(self, user_id: str, data: UpgradeTapRequest) -> UpgradeTapResponse:
        resource = await self.repo.get_resource(user_id, data.resource_type)
        if not resource:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Kaynak bulunamadı")

        # Tıklama upgrade maliyeti altın'dan düşülür
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

    async def get_buildings(self, user_id: str) -> GetBuildingsResponse:
        buildings = await self.repo.get_buildings(user_id)
        return GetBuildingsResponse(
            buildings=[
                BuildingInfo(
                    building_type=b.building_type,
                    level=b.level,
                    resource_type=b.resource_type,
                    production_rate=b.production_rate,
                )
                for b in buildings
            ]
        )

    async def build_or_upgrade(self, user_id: str, data: BuildRequest) -> BuildResponse:
        if data.building_type not in VALID_BUILDINGS:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "Geçersiz bina tipi")

        building = await self.repo.get_building(user_id, data.building_type)
        target_level = (building.level + 1) if building else 1

        costs = building_cost(data.building_type, target_level)

        # Kaynakları kontrol et ve düş
        resources = await self.repo.get_all_resources(user_id)
        resource_map = {r.resource_type: r for r in resources}

        for rtype, amount in costs.items():
            r = resource_map.get(rtype)
            if not r or r.amount < amount:
                raise HTTPException(
                    status.HTTP_400_BAD_REQUEST,
                    f"Yetersiz {rtype.value}. Gerekli: {amount}",
                )

        for rtype, amount in costs.items():
            resource_map[rtype].amount -= amount
            await self.repo.update_resource(resource_map[rtype])

        resource_type = BUILDING_RESOURCE[data.building_type]
        new_rate = AUTO_RATE_PER_LEVEL * target_level

        if building is None:
            building = Building(
                user_id=user_id,
                building_type=data.building_type,
                level=1,
                resource_type=resource_type,
                production_rate=new_rate,
            )
            await self.repo.create_building(building)
        else:
            building.level = target_level
            building.production_rate = new_rate
            await self.repo.update_building(building)

        # Oyuncunun otomatik üretim hızını güncelle
        res = resource_map.get(resource_type)
        if res:
            res.auto_rate = new_rate
            res.auto_level = target_level
            await self.repo.update_resource(res)

        costs_paid = {k.value: v for k, v in costs.items()}

        return BuildResponse(
            building=BuildingInfo(
                building_type=building.building_type,
                level=building.level,
                resource_type=building.resource_type,
                production_rate=building.production_rate,
            ),
            costs_paid=costs_paid,
            new_auto_rate=new_rate,
        )
