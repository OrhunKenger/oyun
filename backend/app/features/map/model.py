from sqlalchemy import Column, String, Integer, ForeignKey, DateTime, UniqueConstraint
from sqlalchemy.sql import func
import uuid

from app.core.database import Base


class MapPixel(Base):
    __tablename__ = "map_pixels"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    x = Column(Integer, nullable=False)
    y = Column(Integer, nullable=False)
    owner_id = Column(String, ForeignKey("users.id"), nullable=True, index=True)
    defense_power = Column(Integer, default=10)
    captured_at = Column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (UniqueConstraint("x", "y", name="uq_pixel_coords"),)
