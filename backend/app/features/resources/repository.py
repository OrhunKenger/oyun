from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.features.resources.model import (
    PlayerResource, ResourceType, Building, PlayerSoldier, SoldierType
)


class ResourceRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    # ── Kaynaklar ────────────────────────────────────────────

    async def get_resource(self, user_id: str, resource_type: ResourceType) -> PlayerResource | None:
        result = await self.db.execute(
            select(PlayerResource).where(
                PlayerResource.user_id == user_id,
                PlayerResource.resource_type == resource_type,
            )
        )
        return result.scalar_one_or_none()

    async def get_all_resources(self, user_id: str) -> list[PlayerResource]:
        result = await self.db.execute(
            select(PlayerResource).where(PlayerResource.user_id == user_id)
        )
        return list(result.scalars().all())

    async def init_player_resources(self, user_id: str) -> list[PlayerResource]:
        resources = []
        for rtype in ResourceType:
            resource = PlayerResource(user_id=user_id, resource_type=rtype)
            self.db.add(resource)
            resources.append(resource)
        await self.db.flush()
        return resources

    async def update_resource(self, resource: PlayerResource) -> PlayerResource:
        await self.db.flush()
        return resource

    # ── Binalar ──────────────────────────────────────────────

    async def get_building(self, user_id: str, building_type: str) -> Building | None:
        result = await self.db.execute(
            select(Building).where(
                Building.user_id == user_id,
                Building.building_type == building_type,
            )
        )
        return result.scalar_one_or_none()

    async def get_buildings(self, user_id: str) -> list[Building]:
        result = await self.db.execute(
            select(Building).where(Building.user_id == user_id)
        )
        return list(result.scalars().all())

    async def create_building(self, building: Building) -> Building:
        self.db.add(building)
        await self.db.flush()
        return building

    async def update_building(self, building: Building) -> Building:
        await self.db.flush()
        return building

    # ── Askerler ─────────────────────────────────────────────

    async def get_soldier(self, user_id: str, soldier_type: SoldierType) -> PlayerSoldier | None:
        result = await self.db.execute(
            select(PlayerSoldier).where(
                PlayerSoldier.user_id == user_id,
                PlayerSoldier.soldier_type == soldier_type,
            )
        )
        return result.scalar_one_or_none()

    async def get_all_soldiers(self, user_id: str) -> list[PlayerSoldier]:
        result = await self.db.execute(
            select(PlayerSoldier).where(PlayerSoldier.user_id == user_id)
        )
        return list(result.scalars().all())

    async def upsert_soldier(self, user_id: str, soldier_type: SoldierType, count_delta: int) -> PlayerSoldier:
        soldier = await self.get_soldier(user_id, soldier_type)
        if soldier is None:
            soldier = PlayerSoldier(user_id=user_id, soldier_type=soldier_type, count=max(0, count_delta))
            self.db.add(soldier)
        else:
            soldier.count = max(0, soldier.count + count_delta)
        await self.db.flush()
        return soldier
