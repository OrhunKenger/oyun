from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.features.auth.router import get_current_user
from app.features.map.repository import MapRepository
from app.features.map.schemas import MapChunkRequest, MapChunkResponse, AttackPixelRequest

router = APIRouter()


@router.get("/chunk", response_model=MapChunkResponse)
async def get_chunk(
    x_start: int = 0,
    y_start: int = 0,
    width: int = 50,
    height: int = 50,
    user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    repo = MapRepository(db)
    pixels = await repo.get_chunk(x_start, y_start, width, height)
    return MapChunkResponse(
        pixels=pixels,
        x_start=x_start,
        y_start=y_start,
        width=width,
        height=height,
    )
