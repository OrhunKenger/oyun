from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.features.auth.router import get_current_user
from app.features.resources.repository import ResourceRepository
from app.features.resources.service import ResourceService
from app.features.resources.schemas import (
    TapRequest, TapResponse, AllResourcesResponse,
    UpgradeTapRequest, UpgradeTapResponse
)

router = APIRouter()


def get_service(db: AsyncSession = Depends(get_db)) -> ResourceService:
    return ResourceService(ResourceRepository(db))


@router.post("/tap", response_model=TapResponse)
async def tap(
    data: TapRequest,
    user=Depends(get_current_user),
    service: ResourceService = Depends(get_service),
):
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
