import random
from datetime import datetime, timezone
from fastapi import HTTPException, status

from app.core.config import settings
from app.features.battle.model import Battle, BattleStatus
from app.features.battle.repository import BattleRepository
from app.features.battle.schemas import (
    StartBattleRequest, StartBattleResponse,
    BattleTapRequest, BattleTapResponse, BattleResult, DamageBreakdown,
)
from app.features.map.repository import MapRepository
from app.features.auth.repository import AuthRepository
from app.features.resources.repository import ResourceRepository
from app.features.resources.power import (
    calc_power, calc_territory_radius,
    calc_attacker_power, calc_defender_power,
)
from app.features.resources.model import ResourceType, SoldierType, SOLDIER_ATTACK


class BattleService:
    def __init__(
        self,
        battle_repo: BattleRepository,
        map_repo: MapRepository,
        auth_repo: AuthRepository,
        res_repo: ResourceRepository | None = None,
    ):
        self.battle_repo = battle_repo
        self.map_repo = map_repo
        self.auth_repo = auth_repo
        self.res_repo = res_repo

    async def start_battle(self, attacker_id: str, data: StartBattleRequest) -> StartBattleResponse:
        # Hedef koordinatta kimin evi var?
        defender = await self._find_owner_at(data.pixel_x, data.pixel_y)

        if defender and defender.id == attacker_id:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "Kendi topraklarına saldıramazsın")

        existing = await self.battle_repo.get_active_on_pixel(data.pixel_x, data.pixel_y)
        if existing:
            raise HTTPException(status.HTTP_409_CONFLICT, "Bu koordinat zaten savaşta")

        battle = Battle(
            attacker_id=attacker_id,
            defender_id=defender.id if defender else None,
            pixel_x=data.pixel_x,
            pixel_y=data.pixel_y,
        )
        battle = await self.battle_repo.create(battle)

        return StartBattleResponse(
            battle_id=battle.id,
            pixel_x=data.pixel_x,
            pixel_y=data.pixel_y,
            duration_seconds=settings.battle_duration_seconds,
            defender_id=defender.id if defender else None,
        )

    async def tap(self, user_id: str, data: BattleTapRequest) -> BattleTapResponse:
        battle = await self.battle_repo.get(data.battle_id)
        if not battle or battle.status != BattleStatus.active:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Aktif savaş bulunamadı")

        elapsed = (datetime.now(timezone.utc) - battle.started_at.replace(tzinfo=timezone.utc)).seconds
        if elapsed >= settings.battle_duration_seconds:
            result = await self._finish_battle(battle)
            return BattleTapResponse(
                battle_id=battle.id,
                attacker_taps=battle.attacker_taps,
                defender_taps=battle.defender_taps,
                status=battle.status,
            )

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

        # Güç hesapla
        attacker_power = 1.0
        defender_power = 1.0
        defender_total_power = 1.0
        defender_territory_radius = 1

        if self.res_repo:
            att_resources = await self.res_repo.get_all_resources(battle.attacker_id)
            att_soldiers = await self.res_repo.get_all_soldiers(battle.attacker_id)
            att_user = await self.auth_repo.get_by_id(battle.attacker_id)
            tap_power = att_user.tap_power if att_user else 1
            attacker_power = calc_attacker_power(att_soldiers, tap_power)

            if battle.defender_id:
                def_resources = await self.res_repo.get_all_resources(battle.defender_id)
                def_buildings = await self.res_repo.get_buildings(battle.defender_id)
                def_soldiers = await self.res_repo.get_all_soldiers(battle.defender_id)
                defender_power = calc_defender_power(def_buildings, def_soldiers)
                defender_total_power = calc_power(def_resources, def_buildings, def_soldiers)
                defender_territory_radius = calc_territory_radius(defender_total_power)

        # Hasar hesabı
        damage_per_tap = (attacker_power / defender_power) * settings.battle_base_damage
        total_damage = battle.attacker_taps * damage_per_tap
        damage_ratio = min(1.5, total_damage / max(defender_total_power, 1))

        # Sonuç belirle
        attacker_wins = battle.attacker_taps > battle.defender_taps
        damage_breakdown = await self._apply_damage(
            battle, damage_ratio, defender_territory_radius
        )

        if attacker_wins:
            battle.status = BattleStatus.attacker_won
            winner_id = battle.attacker_id
            captured = damage_breakdown.pixels_transferred > 0
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
            damage=damage_breakdown,
        )

    async def _apply_damage(
        self, battle: Battle, damage_ratio: float, defender_radius: int
    ) -> DamageBreakdown:
        resources_lost = 0.0
        soldiers_lost = 0
        building_degraded = None
        pixels_transferred = 0
        defender_eliminated = False

        if not battle.defender_id or not self.res_repo or damage_ratio < 0.2:
            # Saldırı püskürtüldü veya boş arazi
            if damage_ratio < 0.2 and battle.defender_id:
                # Saldırana küçük kaynak kaybı
                att_gold = await self.res_repo.get_resource(battle.attacker_id, ResourceType.gold)
                if att_gold:
                    penalty = att_gold.amount * 0.05
                    att_gold.amount = max(0, att_gold.amount - penalty)
                    await self.res_repo.update_resource(att_gold)
            pixels_transferred = 0 if damage_ratio < 0.2 else 1
            return DamageBreakdown(
                total_damage=0,
                damage_ratio=damage_ratio,
                resources_lost=0,
                soldiers_lost=0,
                building_degraded=None,
                pixels_transferred=pixels_transferred,
                defender_eliminated=False,
            )

        # Kaynak kaybı
        def_resources = await self.res_repo.get_all_resources(battle.defender_id)
        total_res = sum(r.amount for r in def_resources)
        resources_lost = total_res * damage_ratio * 0.3

        for r in def_resources:
            loss = r.amount * damage_ratio * 0.3
            r.amount = max(0, r.amount - loss)
            await self.res_repo.update_resource(r)

        # Asker kaybı (zayıftan güçlüye)
        for stype in [SoldierType.swordsman, SoldierType.archer, SoldierType.knight, SoldierType.catapult]:
            s = await self.res_repo.get_soldier(battle.defender_id, stype)
            if s and s.count > 0:
                loss = min(s.count, int(damage_ratio * s.count * 0.5) + 1)
                soldiers_lost += loss
                s.count = max(0, s.count - loss)
                await self.res_repo.db.flush()

        # Bina hasarı
        if damage_ratio > 0.4:
            buildings = await self.res_repo.get_buildings(battle.defender_id)
            if buildings:
                target = random.choice(buildings)
                target.level = max(0, target.level - 1)
                building_degraded = target.building_type
                if target.level == 0:
                    await self.res_repo.db.delete(target)
                await self.res_repo.db.flush()

        # Piksel transferi
        pixels_transferred = int(damage_ratio * (defender_radius ** 2) * 0.3)
        pixels_transferred = max(0, pixels_transferred)

        # Tam sıfırlama
        if damage_ratio >= 1.0:
            defender_eliminated = True
            pixels_transferred = defender_radius ** 2
            defender = await self.auth_repo.get_by_id(battle.defender_id)
            if defender:
                # Saldırganın koordinatlarına yakın bir alan ver veya saldırganı genişlet
                attacker = await self.auth_repo.get_by_id(battle.attacker_id)
                if attacker:
                    attacker.power_score += defender.power_score * 0.5
                # Savunucuyu haritadan sil
                defender.home_x = None
                defender.home_y = None
                defender.power_score = 0.0
                await self.res_repo.db.flush()

        return DamageBreakdown(
            total_damage=battle.attacker_taps * settings.battle_base_damage,
            damage_ratio=damage_ratio,
            resources_lost=resources_lost,
            soldiers_lost=soldiers_lost,
            building_degraded=building_degraded,
            pixels_transferred=pixels_transferred,
            defender_eliminated=defender_eliminated,
        )

    async def _find_owner_at(self, x: int, y: int):
        """(x,y) koordinatının territory'sine sahip oyuncuyu bulur."""
        from sqlalchemy import select, and_
        from app.features.auth.model import User
        from app.features.resources.power import calc_territory_radius, calc_power

        result = await self.map_repo.db.execute(
            select(User).where(User.home_x.isnot(None))
        )
        users = result.scalars().all()

        for u in users:
            if self.res_repo:
                resources = await self.res_repo.get_all_resources(u.id)
                buildings = await self.res_repo.get_buildings(u.id)
                soldiers = await self.res_repo.get_all_soldiers(u.id)
                power = calc_power(resources, buildings, soldiers)
                radius = calc_territory_radius(power)
            else:
                radius = 5
            dist = max(abs(x - u.home_x), abs(y - u.home_y))  # Chebyshev distance
            if dist <= radius:
                return u
        return None
