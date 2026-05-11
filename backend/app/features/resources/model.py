from sqlalchemy import Column, String, Integer, Float, ForeignKey, DateTime, Enum
from sqlalchemy.sql import func
import enum
import uuid

from app.core.database import Base


class ResourceType(str, enum.Enum):
    gold = "gold"
    wood = "wood"
    stone = "stone"
    iron = "iron"
    food = "food"


class SoldierType(str, enum.Enum):
    swordsman = "swordsman"   # Piyade: dengeli
    archer = "archer"         # Okçu: yüksek saldırı
    knight = "knight"         # Süvari: en güçlü
    catapult = "catapult"     # Mancınık: binalara 3x hasar


class BuildingType(str, enum.Enum):
    # Üretim binaları
    sawmill = "sawmill"       # Odun üretir
    quarry = "quarry"         # Taş üretir
    forge = "forge"           # Demir üretir
    treasury = "treasury"     # Altın üretir
    farm = "farm"             # Yiyecek üretir
    # Askeri binalar
    barracks = "barracks"     # Piyade + Okçu eğitir
    stable = "stable"         # Süvari eğitir
    workshop = "workshop"     # Mancınık eğitir
    # Savunma binası
    walls = "walls"           # Düz savunma bonusu


BUILDING_DEF_WEIGHT = {
    "walls": 5,
    "barracks": 2,
    "stable": 2,
    "workshop": 3,
    "sawmill": 1,
    "quarry": 1,
    "forge": 1,
    "treasury": 1,
    "farm": 1,
}

BUILDING_PRODUCES: dict[str, str | None] = {
    "sawmill": "wood",
    "quarry": "stone",
    "forge": "iron",
    "treasury": "gold",
    "farm": "food",
    "barracks": None,
    "stable": None,
    "workshop": None,
    "walls": None,
}

SOLDIER_ATTACK = {"swordsman": 3, "archer": 5, "knight": 8, "catapult": 12}
SOLDIER_DEFENSE = {"swordsman": 3, "archer": 1, "knight": 4, "catapult": 0}

# Geriye uyumluluk için ortalama
FOOD_DRAIN_PER_SOLDIER = 0.03

# Asker tipine göre food tüketimi (food/s)
FOOD_DRAIN_PER_TYPE: dict[str, float] = {
    "swordsman": 0.01,
    "archer":    0.02,
    "knight":    0.06,
    "catapult":  0.10,
}

# Hangi kaynağı hangi bina üretir → storage cap için
RESOURCE_PRODUCER: dict[str, str] = {
    "gold":  "treasury",
    "wood":  "sawmill",
    "stone": "quarry",
    "iron":  "forge",
    "food":  "farm",
}

# Pasif kazanç yakalama tavanı (12 saat)
OFFLINE_CAP_SECONDS = 12 * 3600
# Depo taban kapasitesi ve seviye başına ek
STORAGE_BASE = 1000.0
STORAGE_PER_LEVEL = 5000.0
# Firar parametreleri
DESERTION_CYCLE_SECONDS = 60
DESERTION_RATE = 0.05  # her döngüde %5

BUILDING_BASE_COSTS: dict[str, dict[str, float]] = {
    "sawmill":  {"wood": 50,  "stone": 30},
    "quarry":   {"wood": 40,  "stone": 50},
    "forge":    {"stone": 60, "iron": 20},
    "treasury": {"wood": 50,  "gold": 40},
    "farm":     {"wood": 60,  "stone": 40},
    "barracks": {"wood": 80,  "stone": 60},
    "stable":   {"wood": 100, "iron": 50},
    "workshop": {"iron": 80,  "stone": 60},
    "walls":    {"stone": 100, "iron": 40},
}

SOLDIER_TRAIN_COSTS: dict[str, dict[str, float]] = {
    "swordsman": {"gold": 10, "iron": 5},
    "archer":    {"gold": 10, "wood": 10},
    "knight":    {"gold": 30, "iron": 15, "food": 10},
    "catapult":  {"wood": 50, "iron": 30},
}

SOLDIER_REQUIRED_BUILDING: dict[str, str] = {
    "swordsman": "barracks",
    "archer":    "barracks",
    "knight":    "stable",
    "catapult":  "workshop",
}

# Counter matrisi (RPS): saldıran[satır] vs savunan[sütun] çarpanı
COUNTER_MATRIX: dict[str, dict[str, float]] = {
    "swordsman": {"swordsman": 1.0, "archer": 1.3, "knight": 0.7, "catapult": 1.5},
    "archer":    {"swordsman": 0.7, "archer": 1.0, "knight": 1.5, "catapult": 1.0},
    "knight":    {"swordsman": 1.5, "archer": 0.7, "knight": 1.0, "catapult": 1.0},
    "catapult":  {"swordsman": 0.3, "archer": 0.3, "knight": 0.3, "catapult": 0.5},
}

# Yağma taşıma kapasitesi (toplam birim başına)
SOLDIER_CARRY: dict[str, int] = {
    "swordsman": 50,
    "archer":    30,
    "knight":    100,
    "catapult":  0,  # siege engine, ganimet taşımaz
}

# Catapult binayı vurma çarpanı
CATAPULT_BUILDING_DAMAGE = 3.0
# Eş zamanlı savaş limiti (saldıran VEYA savunan)
MAX_CONCURRENT_BATTLES = 3


class PlayerResource(Base):
    __tablename__ = "player_resources"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, ForeignKey("users.id"), nullable=False, index=True)
    resource_type = Column(Enum(ResourceType), nullable=False)
    amount = Column(Float, default=0.0)

    tap_power = Column(Integer, default=1)
    tap_power_level = Column(Integer, default=1)

    auto_rate = Column(Float, default=0.0)
    auto_level = Column(Integer, default=0)

    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class Building(Base):
    __tablename__ = "buildings"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, ForeignKey("users.id"), nullable=False, index=True)
    building_type = Column(String, nullable=False)
    level = Column(Integer, default=1)
    resource_type = Column(String, nullable=True)  # Ürettiği kaynak (yok ise null)
    production_rate = Column(Float, default=0.0)
    defense_contribution = Column(Float, default=0.0)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class PlayerSoldier(Base):
    __tablename__ = "player_soldiers"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, ForeignKey("users.id"), nullable=False, index=True)
    soldier_type = Column(Enum(SoldierType), nullable=False)
    count = Column(Integer, default=0)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
