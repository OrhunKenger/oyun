from fastapi import APIRouter, Depends, BackgroundTasks
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.config import settings
from app.features.auth.router import get_current_user
from app.features.resources.repository import ResourceRepository
from app.features.resources.service import ResourceService
from app.features.map.repository import MapRepository
from app.features.resources.schemas import (
    TapRequest, TapResponse, AllResourcesResponse,
    UpgradeTapRequest, UpgradeTapResponse,
    BuildRequest, BuildResponse, GetBuildingsResponse,
    TrainRequest, TrainResponse, GetSoldiersResponse,
)

router = APIRouter()


def get_service(db: AsyncSession = Depends(get_db)) -> ResourceService:
    return ResourceService(ResourceRepository(db))


@router.post("/tap", response_model=TapResponse)
async def tap(
    data: TapRequest,
    user=Depends(get_current_user),
    service: ResourceService = Depends(get_service),
    db: AsyncSession = Depends(get_db),
):
    # İlk tap'ta harita konumu ata
    if user.home_x is None:
        map_repo = MapRepository(db)
        await map_repo.assign_home(user, settings.map_width, settings.map_height, settings.home_clearance)
    return await service.tap(user.id, data)


@router.get("/", response_model=AllResourcesResponse)
async def get_resources(
    user=Depends(get_current_user),
    service: ResourceService = Depends(get_service),
):
    return await service.get_all(user.id)


@router.post("/upgrade-tap", response_model=UpgradeTapResponse)
async def upgrade_tap(
    data: UpgradeTapRequest,
    user=Depends(get_current_user),
    service: ResourceService = Depends(get_service),
):
    return await service.upgrade_tap(user.id, data)


@router.get("/buildings", response_model=GetBuildingsResponse)
async def get_buildings(
    user=Depends(get_current_user),
    service: ResourceService = Depends(get_service),
):
    return await service.get_buildings(user.id)


@router.post("/build", response_model=BuildResponse)
async def build_or_upgrade(
    data: BuildRequest,
    user=Depends(get_current_user),
    service: ResourceService = Depends(get_service),
):
    return await service.build_or_upgrade(user.id, data)


@router.get("/soldiers", response_model=GetSoldiersResponse)
async def get_soldiers(
    user=Depends(get_current_user),
    service: ResourceService = Depends(get_service),
):
    return await service.get_soldiers(user.id)


@router.post("/train", response_model=TrainResponse)
async def train_soldiers(
    data: TrainRequest,
    user=Depends(get_current_user),
    service: ResourceService = Depends(get_service),
):
    return await service.train_soldiers(user.id, data)
