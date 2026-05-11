from pydantic import BaseModel, EmailStr
from enum import Enum


class AuthProvider(str, Enum):
    email = "email"
    google = "google"
    apple = "apple"


class RegisterRequest(BaseModel):
    email: EmailStr
    username: str
    password: str


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class SocialAuthRequest(BaseModel):
    provider: AuthProvider
    token: str  # Google/Apple token


class AuthResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: str
    username: str


class UserProfile(BaseModel):
    id: str
    email: str
    username: str
    level: int
    prestige: int
    pixel_count: int
    total_score: int
    tap_power: int
    home_x: int | None = None
    home_y: int | None = None
    power_score: float = 0.0

    class Config:
        from_attributes = True
