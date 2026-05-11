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
    map_width: int = 2000
    map_height: int = 2000
    season_duration_days: int = 28
    battle_duration_seconds: int = 30

    # Savaş
    battle_base_damage: float = 10.0
    home_clearance: int = 10  # Yeni ev için minimum boşluk

    # Güç formülü ağırlıkları
    power_weight_resources: float = 0.20
    power_weight_buildings: float = 0.30
    power_weight_soldiers: float = 0.50

    class Config:
        env_file = ".env"


settings = Settings()
