from sqlalchemy import Column, String, DateTime, Integer, Float, Enum
from sqlalchemy.sql import func
import enum
import uuid

from app.core.database import Base


class AuthProvider(str, enum.Enum):
    email = "email"
    google = "google"
    apple = "apple"


class User(Base):
    __tablename__ = "users"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    email = Column(String, unique=True, nullable=False, index=True)
    username = Column(String, unique=True, nullable=False)
    password_hash = Column(String, nullable=True)
    auth_provider = Column(Enum(AuthProvider), default=AuthProvider.email)
    provider_id = Column(String, nullable=True)

    # Oyun istatistikleri
    level = Column(Integer, default=1)
    prestige = Column(Integer, default=0)
    pixel_count = Column(Integer, default=0)
    total_score = Column(Integer, default=0)
    tap_power = Column(Integer, default=1)
    power_score = Column(Float, default=0.0)

    # Harita koordinatı (ilk kaynak toplandığında atanır)
    home_x = Column(Integer, nullable=True)
    home_y = Column(Integer, nullable=True)

    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
