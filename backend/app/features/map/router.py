from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.config import settings
from app.features.auth.router import get_current_user
from app.features.map.repository import MapRepository
from app.features.map.schemas import MapChunkResponse, PlayerTerritory
from app.features.resources.repository import ResourceRepository
from app.features.resources.power import calc_power, calc_territory_radius

router = APIRouter()


def _color_hue(user_id: str) -> int:
    """Kullanıcı ID'sine göre deterministik renk tonu (0-360)."""
    return abs(hash(user_id)) % 360


@router.get("/chunk", response_model=MapChunkResponse)
async def get_chunk(
    x_start: int = 0,
    y_start: int = 0,
    width: int = 50,
    height: int = 50,
    user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    map_repo = MapRepository(db)
    res_repo = ResourceRepository(db)

    players = await map_repo.get_players_in_chunk(x_start, y_start, width, height)

    territories = []
    for p in players:
        resources = await res_repo.get_all_resources(p.id)
        buildings = await res_repo.get_buildings(p.id)
        soldiers = await res_repo.get_all_soldiers(p.id)

        power = calc_power(resources, buildings, soldiers)
        radius = calc_territory_radius(power)

        territories.append(PlayerTerritory(
            user_id=p.id,
            username=p.username,
            home_x=p.home_x,
            home_y=p.home_y,
            power_score=power,
            territory_radius=radius,
            color_hue=_color_hue(p.id),
        ))

    return MapChunkResponse(
        players=territories,
        x_start=x_start,
        y_start=y_start,
        width=width,
        height=height,
    )


@router.post("/assign-home")
async def assign_home(
    user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if user.home_x is not None:
        return {"home_x": user.home_x, "home_y": user.home_y, "assigned": False}

    repo = MapRepository(db)
    x, y = await repo.assign_home(user, settings.map_width, settings.map_height, settings.home_clearance)
    return {"home_x": x, "home_y": y, "assigned": True}
