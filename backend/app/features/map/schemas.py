from pydantic import BaseModel


class PixelInfo(BaseModel):
    x: int
    y: int
    owner_id: str | None
    owner_username: str | None
    defense_power: int

    class Config:
        from_attributes = True


class PlayerTerritory(BaseModel):
    user_id: str
    username: str
    home_x: int
    home_y: int
    power_score: float
    territory_radius: int
    color_hue: int  # 0-360, her oyuncuya sabit renk tonu


class MapChunkRequest(BaseModel):
    x_start: int
    y_start: int
    width: int = 50
    height: int = 50


class MapChunkResponse(BaseModel):
    players: list[PlayerTerritory]
    x_start: int
    y_start: int
    width: int
    height: int


class AttackPixelRequest(BaseModel):
    x: int
    y: int
