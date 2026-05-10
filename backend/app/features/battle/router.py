from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.features.auth.router import get_current_user
from app.features.auth.repository import AuthRepository
from app.features.battle.repository import BattleRepository
from app.features.battle.service import BattleService
from app.features.battle.schemas import (
    StartBattleRequest, StartBattleResponse,
    BattleTapRequest, BattleTapResponse, BattleResult
)
from app.features.map.repository import MapRepository

router = APIRouter()


def get_service(db: AsyncSession = Depends(get_db)) -> BattleService:
    return BattleService(BattleRepository(db), MapRepository(db), AuthRepository(db))


@router.post("/start", response_model=StartBattleResponse)
async def start_battle(
    data: StartBattleRequest,
    user=Depends(get_current_user),
    service: BattleService = Depends(get_service),
):
    return await service.start_battle(user.id, data)


@router.post("/tap", response_model=BattleTapResponse)
async def battle_tap(
    data: BattleTapRequest,
    user=Depends(get_current_user),
    service: BattleService = Depends(get_service),
):
    return await service.tap(user.id, data)


@router.post("/{battle_id}/finish", response_model=BattleResult)
async def finish_battle(
    battle_id: str,
    user=Depends(get_current_user),
    service: BattleService = Depends(get_service),
):
    return await service.finish_battle(battle_id)
