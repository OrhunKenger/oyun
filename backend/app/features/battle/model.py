from sqlalchemy import Column, String, Integer, ForeignKey, DateTime, Enum, Boolean
from sqlalchemy.sql import func
import enum
import uuid

from app.core.database import Base


class BattleStatus(str, enum.Enum):
    active = "active"
    attacker_won = "attacker_won"
    defender_won = "defender_won"


class Battle(Base):
    __tablename__ = "battles"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    attacker_id = Column(String, ForeignKey("users.id"), nullable=False)
    defender_id = Column(String, ForeignKey("users.id"), nullable=True)
    pixel_x = Column(Integer, nullable=False)
    pixel_y = Column(Integer, nullable=False)

    attacker_taps = Column(Integer, default=0)
    defender_taps = Column(Integer, default=0)

    status = Column(Enum(BattleStatus), default=BattleStatus.active)
    started_at = Column(DateTime(timezone=True), server_default=func.now())
    ended_at = Column(DateTime(timezone=True), nullable=True)
