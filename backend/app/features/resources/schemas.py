from pydantic import BaseModel
from enum import Enum


class ResourceType(str, Enum):
    gold = "gold"
    wood = "wood"
    stone = "stone"
    iron = "iron"
    food = "food"


class SoldierType(str, Enum):
    swordsman = "swordsman"
    archer = "archer"
    knight = "knight"
    catapult = "catapult"


class TapRequest(BaseModel):
    resource_type: ResourceType
    tap_count: int = 1


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
    storage_cap: float = 1000.0
    is_capped: bool = False

    class Config:
        from_attributes = True


class AllResourcesResponse(BaseModel):
    gold: ResourceState
    wood: ResourceState
    stone: ResourceState
    iron: ResourceState
    food: ResourceState
    offline_gains: dict[str, float] = {}
    offline_seconds: float = 0.0
    desertions: dict[str, int] = {}


class UpgradeTapRequest(BaseModel):
    resource_type: ResourceType


class UpgradeTapResponse(BaseModel):
    resource_type: ResourceType
    new_tap_power: int
    new_level: int
    cost: dict


class BuildingInfo(BaseModel):
    building_type: str
    level: int
    resource_type: str | None
    production_rate: float
    defense_contribution: float

    class Config:
        from_attributes = True


class BuildRequest(BaseModel):
    building_type: str


class BuildResponse(BaseModel):
    building: BuildingInfo
    costs_paid: dict
    new_auto_rate: float


class GetBuildingsResponse(BaseModel):
    buildings: list[BuildingInfo]


class SoldierInfo(BaseModel):
    soldier_type: SoldierType
    count: int
    attack_power: int
    defense_power: int
    train_cost: dict

    class Config:
        from_attributes = True


class TrainRequest(BaseModel):
    soldier_type: SoldierType
    amount: int = 1


class TrainResponse(BaseModel):
    soldier_type: SoldierType
    new_count: int
    costs_paid: dict


class GetSoldiersResponse(BaseModel):
    soldiers: list[SoldierInfo]
    total_attack: int
    total_defense: int
