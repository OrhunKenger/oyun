from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    app_name: str = "Pixel War API"
    debug: bool = False
    secret_key: str
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 60 * 24 * 7  # 7 gün

    database_url: str
    redis_url: str = "redis://localhost:6379"

    google_client_id: str
    apple_client_id: str

    # Oyun sabitleri
    map_width: int = 200
    map_height: int = 200
    season_duration_days: int = 28
    battle_duration_seconds: int = 30

    class Config:
        env_file = ".env"


settings = Settings()
