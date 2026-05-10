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


class PlayerResource(Base):
    __tablename__ = "player_resources"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, ForeignKey("users.id"), nullable=False, index=True)
    resource_type = Column(Enum(ResourceType), nullable=False)
    amount = Column(Float, default=0.0)

    # Tıklama gücü (bu kaynağa özel)
    tap_power = Column(Integer, default=1)
    tap_power_level = Column(Integer, default=1)

    # Otomatik üretim
    auto_rate = Column(Float, default=0.0)  # saniyede üretim
    auto_level = Column(Integer, default=0)

    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class Building(Base):
    __tablename__ = "buildings"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, ForeignKey("users.id"), nullable=False, index=True)
    building_type = Column(String, nullable=False)  # sawmill, mine, quarry, forge
    level = Column(Integer, default=1)
    resource_type = Column(Enum(ResourceType), nullable=False)
    production_rate = Column(Float, default=1.0)  # saniyede üretim
    created_at = Column(DateTime(timezone=True), server_default=func.now())
