from pydantic import BaseModel


class PixelInfo(BaseModel):
    x: int
    y: int
    owner_id: str | None
    owner_username: str | None
    defense_power: int

    class Config:
        from_attributes = True


class MapChunkRequest(BaseModel):
    x_start: int
    y_start: int
    width: int = 50
    height: int = 50


class MapChunkResponse(BaseModel):
    pixels: list[PixelInfo]
    x_start: int
    y_start: int
    width: int
    height: int


class AttackPixelRequest(BaseModel):
    x: int
    y: int
