from datetime import datetime, timezone
from fastapi import HTTPException, status

from app.core.config import settings
from app.features.battle.model import Battle, BattleStatus
from app.features.battle.repository import BattleRepository
from app.features.battle.schemas import (
    StartBattleRequest, StartBattleResponse,
    BattleTapRequest, BattleTapResponse, BattleResult
)
from app.features.map.repository import MapRepository
from app.features.auth.repository import AuthRepository


class BattleService:
    def __init__(self, battle_repo: BattleRepository, map_repo: MapRepository, auth_repo: AuthRepository):
        self.battle_repo = battle_repo
        self.map_repo = map_repo
        self.auth_repo = auth_repo

    async def start_battle(self, attacker_id: str, data: StartBattleRequest) -> StartBattleResponse:
        pixel = await self.map_repo.get_pixel(data.pixel_x, data.pixel_y)

        # Kendi pikselini saldıramazsın
        if pixel and pixel.owner_id == attacker_id:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "Kendi pikselini saldıramazsın")

        # Zaten aktif savaş var mı
        existing = await self.battle_repo.get_active_on_pixel(data.pixel_x, data.pixel_y)
        if existing:
            raise HTTPException(status.HTTP_409_CONFLICT, "Bu piksel zaten savaşta")

        defender_id = pixel.owner_id if pixel else None

        battle = Battle(
            attacker_id=attacker_id,
            defender_id=defender_id,
            pixel_x=data.pixel_x,
            pixel_y=data.pixel_y,
        )
        battle = await self.battle_repo.create(battle)

        return StartBattleResponse(
            battle_id=battle.id,
            pixel_x=data.pixel_x,
            pixel_y=data.pixel_y,
            duration_seconds=settings.battle_duration_seconds,
            defender_id=defender_id,
        )

    async def tap(self, user_id: str, data: BattleTapRequest) -> BattleTapResponse:
        battle = await self.battle_repo.get(data.battle_id)
        if not battle or battle.status != BattleStatus.active:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Aktif savaş bulunamadı")

        # Süre doldu mu kontrol et
        elapsed = (datetime.now(timezone.utc) - battle.started_at.replace(tzinfo=timezone.utc)).seconds
        if elapsed >= settings.battle_duration_seconds:
            return await self._finish_battle(battle)

        if user_id == battle.attacker_id:
            battle.attacker_taps += data.tap_count
        elif user_id == battle.defender_id:
            battle.defender_taps += data.tap_count
        else:
            raise HTTPException(status.HTTP_403_FORBIDDEN, "Bu savaşa katılamazsın")

        await self.battle_repo.update(battle)

        return BattleTapResponse(
            battle_id=battle.id,
            attacker_taps=battle.attacker_taps,
            defender_taps=battle.defender_taps,
            status=battle.status,
        )

    async def finish_battle(self, battle_id: str) -> BattleResult:
        battle = await self.battle_repo.get(battle_id)
        if not battle:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Savaş bulunamadı")
        return await self._finish_battle(battle)

    async def _finish_battle(self, battle: Battle) -> BattleResult:
        if battle.status != BattleStatus.active:
            return BattleResult(
                battle_id=battle.id,
                winner_id=battle.attacker_id if battle.status == BattleStatus.attacker_won else battle.defender_id,
                attacker_taps=battle.attacker_taps,
                defender_taps=battle.defender_taps,
                pixel_captured=battle.status == BattleStatus.attacker_won,
                status=battle.status,
            )

        attacker_won = battle.attacker_taps > battle.defender_taps

        if attacker_won:
            battle.status = BattleStatus.attacker_won
            # Pikseli saldırgana ver
            attacker = await self.auth_repo.get_by_id(battle.attacker_id)
            defense = max(10, battle.attacker_taps // 2)
            await self.map_repo.create_or_update_pixel(battle.pixel_x, battle.pixel_y, battle.attacker_id, defense)
            winner_id = battle.attacker_id
            captured = True
        else:
            battle.status = BattleStatus.defender_won
            winner_id = battle.defender_id
            captured = False

        battle.ended_at = datetime.now(timezone.utc)
        await self.battle_repo.update(battle)

        return BattleResult(
            battle_id=battle.id,
            winner_id=winner_id,
            attacker_taps=battle.attacker_taps,
            defender_taps=battle.defender_taps,
            pixel_captured=captured,
            status=battle.status,
        )
