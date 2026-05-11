import random
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_

from app.features.map.model import MapPixel
from app.features.auth.model import User


class MapRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_pixel(self, x: int, y: int) -> MapPixel | None:
        result = await self.db.execute(
            select(MapPixel).where(MapPixel.x == x, MapPixel.y == y)
        )
        return result.scalar_one_or_none()

    async def get_chunk(self, x_start: int, y_start: int, width: int, height: int) -> list[MapPixel]:
        result = await self.db.execute(
            select(MapPixel).where(
                MapPixel.x >= x_start,
                MapPixel.x < x_start + width,
                MapPixel.y >= y_start,
                MapPixel.y < y_start + height,
            )
        )
        return list(result.scalars().all())

    async def get_players_in_chunk(self, x_start: int, y_start: int, width: int, height: int) -> list[User]:
        """Chunk bölgesinde home koordinatı olan tüm oyuncuları döner."""
        margin = 30  # territory_radius max = 30
        result = await self.db.execute(
            select(User).where(
                and_(
                    User.home_x.isnot(None),
                    User.home_x >= x_start - margin,
                    User.home_x < x_start + width + margin,
                    User.home_y >= y_start - margin,
                    User.home_y < y_start + height + margin,
                )
            )
        )
        return list(result.scalars().all())

    async def get_player_pixel_count(self, user_id: str) -> int:
        result = await self.db.execute(
            select(func.count()).where(MapPixel.owner_id == user_id)
        )
        return result.scalar() or 0

    async def create_or_update_pixel(self, x: int, y: int, owner_id: str, defense_power: int) -> MapPixel:
        pixel = await self.get_pixel(x, y)
        if pixel:
            pixel.owner_id = owner_id
            pixel.defense_power = defense_power
        else:
            pixel = MapPixel(x=x, y=y, owner_id=owner_id, defense_power=defense_power)
            self.db.add(pixel)
        await self.db.flush()
        return pixel

    async def assign_home(self, user: User, map_width: int, map_height: int, clearance: int) -> tuple[int, int]:
        """Kullanıcıya boş bir ev koordinatı atar."""
        occupied = await self.db.execute(
            select(User.home_x, User.home_y).where(User.home_x.isnot(None))
        )
        taken = {(r[0], r[1]) for r in occupied.all()}

        for _ in range(500):
            x = random.randint(clearance, map_width - clearance)
            y = random.randint(clearance, map_height - clearance)
            # Etrafında clearance mesafesinde başka ev yok mu?
            conflict = any(
                abs(x - tx) < clearance and abs(y - ty) < clearance
                for tx, ty in taken
            )
            if not conflict:
                user.home_x = x
                user.home_y = y
                await self.db.flush()
                return x, y

        # 500 denemede bulunamazsa rastgele ata
        x, y = random.randint(0, map_width), random.randint(0, map_height)
        user.home_x = x
        user.home_y = y
        await self.db.flush()
        return x, y

    async def get_neighbors(self, x: int, y: int) -> list[MapPixel]:
        coords = [(x-1, y), (x+1, y), (x, y-1), (x, y+1)]
        pixels = []
        for cx, cy in coords:
            p = await self.get_pixel(cx, cy)
            if p:
                pixels.append(p)
        return pixels
