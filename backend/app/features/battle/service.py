import math
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
    calc_defender_power, effective_attack,
    carry_capacity, distribute_losses,
)
from app.features.resources.model import (
    ResourceType, SoldierType, SOLDIER_ATTACK,
    MAX_CONCURRENT_BATTLES, CATAPULT_BUILDING_DAMAGE,
)
from app.features.resources.service import storage_cap_for


# Tap morale: rally puanı sqrt edilir, [0.5, 1.5] aralığında clip
def _tap_morale(att_taps: int, def_taps: int) -> float:
    ratio = att_taps / max(def_taps, 1)
    morale = math.sqrt(max(ratio, 0.0001))
    return max(0.5, min(1.5, morale))


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
        # Eş zamanlı savaş limiti
        active_count = await self.battle_repo.count_active_for_user(attacker_id)
        if active_count >= MAX_CONCURRENT_BATTLES:
            raise HTTPException(
                status.HTTP_409_CONFLICT,
                f"Aynı anda maksimum {MAX_CONCURRENT_BATTLES} savaşta olabilirsin",
            )

        # Saldıran ordusu var mı?
        if self.res_repo:
            att_soldiers = await self.res_repo.get_all_soldiers(attacker_id)
            if not any(s.count > 0 for s in att_soldiers):
                raise HTTPException(
                    status.HTTP_400_BAD_REQUEST,
                    "Saldırı için en az bir asker eğitmen gerek",
                )

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
            await self._finish_battle(battle)
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

        # ── Güç ve hasar hesabı ──
        if not self.res_repo:
            # Düşük seviyeli fallback
            battle.status = BattleStatus.attacker_won if battle.attacker_taps > battle.defender_taps else BattleStatus.defender_won
            battle.ended_at = datetime.now(timezone.utc)
            await self.battle_repo.update(battle)
            return BattleResult(
                battle_id=battle.id,
                winner_id=battle.attacker_id if battle.status == BattleStatus.attacker_won else battle.defender_id,
                attacker_taps=battle.attacker_taps,
                defender_taps=battle.defender_taps,
                pixel_captured=battle.status == BattleStatus.attacker_won,
                status=battle.status,
            )

        att_soldiers = await self.res_repo.get_all_soldiers(battle.attacker_id)
        att_resources = await self.res_repo.get_all_resources(battle.attacker_id)
        att_buildings = await self.res_repo.get_buildings(battle.attacker_id)

        if battle.defender_id:
            def_soldiers = await self.res_repo.get_all_soldiers(battle.defender_id)
            def_resources = await self.res_repo.get_all_resources(battle.defender_id)
            def_buildings = await self.res_repo.get_buildings(battle.defender_id)
            def_power = calc_defender_power(def_buildings, def_soldiers)
            def_total_power = calc_power(def_resources, def_buildings, def_soldiers)
            def_radius = calc_territory_radius(def_total_power)
        else:
            def_soldiers = []
            def_resources = []
            def_buildings = []
            def_power = 1.0
            def_total_power = 1.0
            def_radius = 1

        # Counter matrisi ile efektif atak
        eff_atk = effective_attack(att_soldiers, def_soldiers)
        morale = _tap_morale(battle.attacker_taps, battle.defender_taps)
        damage_ratio = (eff_atk * morale) / max(def_power, 1.0)

        damage_breakdown = await self._apply_damage(
            battle=battle,
            damage_ratio=damage_ratio,
            att_soldiers=att_soldiers,
            att_resources=att_resources,
            att_buildings=att_buildings,
            def_soldiers=def_soldiers,
            def_resources=def_resources,
            def_buildings=def_buildings,
            def_radius=def_radius,
            def_total_power=def_total_power,
        )

        # Galibiyet damage_ratio bazlı
        if damage_ratio >= 1.0:
            battle.status = BattleStatus.attacker_won
            winner_id = battle.attacker_id
            captured = damage_breakdown.pixels_transferred > 0
        else:
            battle.status = BattleStatus.defender_won
            winner_id = battle.defender_id
            captured = False

        battle.ended_at = datetime.now(timezone.utc)
        await self.battle_repo.update(battle)
        await self.res_repo.db.flush()

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
        self,
        battle: Battle,
        damage_ratio: float,
        att_soldiers,
        att_resources,
        att_buildings,
        def_soldiers,
        def_resources,
        def_buildings,
        def_radius: int,
        def_total_power: float,
    ) -> DamageBreakdown:
        loot: dict[str, float] = {}
        attacker_loss_breakdown: dict[str, int] = {}
        defender_loss_breakdown: dict[str, int] = {}
        building_degraded: str | None = None
        defender_eliminated = False
        pixels_transferred = 0

        # ── Kayıp yüzdesi belirle ──
        if damage_ratio >= 1.0:
            # Tam galibiyet
            atk_loss_pct = 0.25
            def_loss_pct = 0.60
            loot_factor = 0.5
        elif damage_ratio >= 0.5:
            # Kısmi galibiyet
            atk_loss_pct = 0.45
            def_loss_pct = 0.45
            loot_factor = 0.25
        else:
            # Saldırgan püskürtüldü
            atk_loss_pct = 0.65
            def_loss_pct = 0.20
            loot_factor = 0.0

        # ── Asker kayıpları (counter-bazlı dağılım) ──
        if att_soldiers:
            attacker_loss_breakdown = distribute_losses(atk_loss_pct, att_soldiers, def_soldiers)
            for s in att_soldiers:
                key = s.soldier_type.value if isinstance(s.soldier_type, SoldierType) else s.soldier_type
                loss = attacker_loss_breakdown.get(key, 0)
                if loss > 0:
                    s.count = max(0, s.count - loss)
        if def_soldiers:
            defender_loss_breakdown = distribute_losses(def_loss_pct, def_soldiers, att_soldiers)
            for s in def_soldiers:
                key = s.soldier_type.value if isinstance(s.soldier_type, SoldierType) else s.soldier_type
                loss = defender_loss_breakdown.get(key, 0)
                if loss > 0:
                    s.count = max(0, s.count - loss)
        await self.res_repo.db.flush()

        # ── Mancınık bina hasarı (sadece catapult varsa, walls önce emer) ──
        if battle.defender_id and damage_ratio >= 0.3:
            catapult_count = next(
                (s.count for s in att_soldiers if (
                    s.soldier_type.value if isinstance(s.soldier_type, SoldierType) else s.soldier_type
                ) == "catapult"),
                0,
            )
            if catapult_count > 0:
                walls = next((b for b in def_buildings if b.building_type == "walls"), None)
                walls_armor = walls.level if walls else 0
                effective_catapults = max(0, catapult_count - walls_armor)
                non_walls = [b for b in def_buildings if b.building_type != "walls" and b.level > 0]
                if effective_catapults > 0 and non_walls:
                    building_hits = max(1, int(effective_catapults * (damage_ratio + 0.2) / 5))
                    for _ in range(min(building_hits, len(non_walls) * 3)):
                        if not non_walls:
                            break
                        target = random.choice(non_walls)
                        target.level = max(0, target.level - 1)
                        if building_degraded is None:
                            building_degraded = target.building_type
                        if target.level == 0:
                            non_walls.remove(target)
                            await self.res_repo.db.delete(target)
                    await self.res_repo.db.flush()

        # ── Yağma (loot) ──
        resources_lost_total = 0.0
        if battle.defender_id and loot_factor > 0 and def_resources:
            def_total_res = sum(r.amount for r in def_resources)
            loot_target = def_total_res * damage_ratio * loot_factor

            # Sağ kalan saldıran asker kapasitesi
            survivors_pct = 1 - atk_loss_pct
            carry = carry_capacity(att_soldiers, surviving_pct=survivors_pct)
            loot_total = min(loot_target, carry)

            if loot_total > 0 and def_total_res > 0:
                # Saldıran kaynaklarını cap için lazım
                att_res_map = {r.resource_type: r for r in att_resources}
                for r in def_resources:
                    if r.amount <= 0:
                        continue
                    share = (r.amount / def_total_res) * loot_total
                    actually = min(r.amount, share)
                    r.amount -= actually
                    resources_lost_total += actually

                    # Saldırana ekle (cap'le)
                    att_r = att_res_map.get(r.resource_type)
                    if att_r:
                        cap = storage_cap_for(r.resource_type, att_buildings)
                        room = cap - att_r.amount
                        added = min(actually, max(0, room))
                        att_r.amount += added
                        loot[r.resource_type.value] = round(added, 2)
                await self.res_repo.db.flush()

        # ── Saldırgan püskürtüldüyse altın cezası ──
        if damage_ratio < 0.5 and battle.defender_id:
            att_gold = next((r for r in att_resources if r.resource_type == ResourceType.gold), None)
            if att_gold:
                penalty = att_gold.amount * 0.05
                att_gold.amount = max(0, att_gold.amount - penalty)
            await self.res_repo.db.flush()

        # ── Toprak transferi ──
        if damage_ratio >= 1.0 and battle.defender_id:
            pixels_transferred = max(1, int(damage_ratio * (def_radius ** 2) * 0.3))
            if damage_ratio >= 1.5:
                # Eziyor → defender wiped
                defender_eliminated = True
                pixels_transferred = def_radius ** 2
                defender = await self.auth_repo.get_by_id(battle.defender_id)
                if defender:
                    attacker = await self.auth_repo.get_by_id(battle.attacker_id)
                    if attacker:
                        attacker.power_score = (attacker.power_score or 0) + (defender.power_score or 0) * 0.5
                    defender.home_x = None
                    defender.home_y = None
                    defender.power_score = 0.0
                    await self.res_repo.db.flush()
        elif damage_ratio >= 1.0 and not battle.defender_id:
            # Boş arazi: tek piksel
            pixels_transferred = 1

        # ── Power score recompute ──
        if self.res_repo:
            attacker = await self.auth_repo.get_by_id(battle.attacker_id)
            if attacker and not defender_eliminated:
                attacker.power_score = calc_power(att_resources, att_buildings, att_soldiers)
            if battle.defender_id and not defender_eliminated:
                defender = await self.auth_repo.get_by_id(battle.defender_id)
                if defender:
                    defender.power_score = calc_power(def_resources, def_buildings, def_soldiers)
            await self.res_repo.db.flush()

        total_atk_loss = sum(attacker_loss_breakdown.values())
        total_def_loss = sum(defender_loss_breakdown.values())

        return DamageBreakdown(
            total_damage=round(damage_ratio * max(def_total_power, 1), 2),
            damage_ratio=round(damage_ratio, 3),
            resources_lost=round(resources_lost_total, 2),
            soldiers_lost=total_def_loss,
            building_degraded=building_degraded,
            pixels_transferred=pixels_transferred,
            defender_eliminated=defender_eliminated,
            loot=loot,
            attacker_losses=total_atk_loss,
            attacker_loss_breakdown=attacker_loss_breakdown,
            defender_loss_breakdown=defender_loss_breakdown,
        )

    async def _find_owner_at(self, x: int, y: int):
        """(x,y) koordinatının territory'sine sahip oyuncuyu bulur."""
        from sqlalchemy import select
        from app.features.auth.model import User

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
            dist = max(abs(x - u.home_x), abs(y - u.home_y))
            if dist <= radius:
                return u
        return None
