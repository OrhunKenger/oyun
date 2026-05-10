from pydantic import BaseModel
from enum import Enum


class ResourceType(str, Enum):
    gold = "gold"
    wood = "wood"
    stone = "stone"
    iron = "iron"


class TapRequest(BaseModel):
    resource_type: ResourceType
    tap_count: int = 1  # çoklu tap (hızlı tıklama için batch)


class TapResponse(BaseModel):
    resource_type: ResourceType
    gained: float
    total: float
    tap_power: int


class ResourceState(BaseModel):
    resource_type: ResourceType
    amount: float
    tap_power: int
    tap_power_level: int
    auto_rate: float
    auto_level: int

    class Config:
        from_attributes = True


class AllResourcesResponse(BaseModel):
    gold: ResourceState
    wood: ResourceState
    stone: ResourceState
    iron: ResourceState


class UpgradeTapRequest(BaseModel):
    resource_type: ResourceType


class UpgradeTapResponse(BaseModel):
    resource_type: ResourceType
    new_tap_power: int
    new_level: int
    cost: dict  # hangi kaynaktan ne kadar harcandı


class BuildingInfo(BaseModel):
    building_type: str
    level: int
    resource_type: ResourceType
    production_rate: float

    class Config:
        from_attributes = True
