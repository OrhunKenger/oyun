import math
from fastapi import HTTPException, status

from app.features.resources.model import ResourceType
from app.features.resources.repository import ResourceRepository
from app.features.resources.schemas import (
    TapRequest, TapResponse, AllResourcesResponse, ResourceState,
    UpgradeTapRequest, UpgradeTapResponse
)

# Her seviye için tıklama gücü artışı
TAP_POWER_MULTIPLIER = 2.0

# Tıklama upgrade maliyeti (altın)
def tap_upgrade_cost(current_level: int) -> float:
    return 100 * (3 ** current_level)

# Kaynak tipi → bina adı → otomatik üretim sağlayan bina
RESOURCE_BUILDINGS = {
    ResourceType.gold: "treasury",
    ResourceType.wood: "sawmill",
    ResourceType.stone: "quarry",
    ResourceType.iron: "forge",
}


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
