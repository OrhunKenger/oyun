from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.features.battle.model import Battle, BattleStatus


class BattleRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def create(self, battle: Battle) -> Battle:
        self.db.add(battle)
        await self.db.flush()
        return battle

    async def get(self, battle_id: str) -> Battle | None:
        result = await self.db.execute(select(Battle).where(Battle.id == battle_id))
        return result.scalar_one_or_none()

    async def get_active_on_pixel(self, x: int, y: int) -> Battle | None:
        result = await self.db.execute(
            select(Battle).where(
                Battle.pixel_x == x,
                Battle.pixel_y == y,
                Battle.status == BattleStatus.active,
            )
        )
        return result.scalar_one_or_none()

    async def update(self, battle: Battle) -> Battle:
        await self.db.flush()
        return battle
