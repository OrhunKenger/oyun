class ResourceState {
  final String resourceType;
  final double amount;
  final int tapPower;
  final int tapPowerLevel;
  final double autoRate;
  final int autoLevel;

  ResourceState({
    required this.resourceType,
    required this.amount,
    required this.tapPower,
    required this.tapPowerLevel,
    required this.autoRate,
    required this.autoLevel,
  });

  factory ResourceState.fromJson(Map<String, dynamic> json) => ResourceState(
        resourceType: json['resource_type'],
        amount: (json['amount'] as num).toDouble(),
        tapPower: json['tap_power'],
        tapPowerLevel: json['tap_power_level'],
        autoRate: (json['auto_rate'] as num).toDouble(),
        autoLevel: json['auto_level'],
      );

  ResourceState copyWith({double? amount}) => ResourceState(
        resourceType: resourceType,
        amount: amount ?? this.amount,
        tapPower: tapPower,
        tapPowerLevel: tapPowerLevel,
        autoRate: autoRate,
        autoLevel: autoLevel,
      );
}

class AllResourcesModel {
  final ResourceState gold;
  final ResourceState wood;
  final ResourceState stone;
  final ResourceState iron;
  final ResourceState food;

  AllResourcesModel({
    required this.gold,
    required this.wood,
    required this.stone,
    required this.iron,
    required this.food,
  });

  factory AllResourcesModel.fromJson(Map<String, dynamic> json) => AllResourcesModel(
        gold: ResourceState.fromJson(json['gold']),
        wood: ResourceState.fromJson(json['wood']),
        stone: ResourceState.fromJson(json['stone']),
        iron: ResourceState.fromJson(json['iron']),
        food: ResourceState.fromJson(json['food']),
      );
}

class BuildingModel {
  final String buildingType;
  final int level;
  final String? resourceType;
  final double productionRate;
  final double defenseContribution;

  BuildingModel({
    required this.buildingType,
    required this.level,
    this.resourceType,
    required this.productionRate,
    required this.defenseContribution,
  });

  factory BuildingModel.fromJson(Map<String, dynamic> json) => BuildingModel(
        buildingType: json['building_type'],
        level: json['level'],
        resourceType: json['resource_type'],
        productionRate: (json['production_rate'] as num).toDouble(),
        defenseContribution: (json['defense_contribution'] as num).toDouble(),
      );
}

class SoldierModel {
  final String soldierType;
  final int count;
  final int attackPower;
  final int defensePower;
  final Map<String, double> trainCost;

  SoldierModel({
    required this.soldierType,
    required this.count,
    required this.attackPower,
    required this.defensePower,
    required this.trainCost,
  });

  factory SoldierModel.fromJson(Map<String, dynamic> json) => SoldierModel(
        soldierType: json['soldier_type'],
        count: json['count'],
        attackPower: json['attack_power'],
        defensePower: json['defense_power'],
        trainCost: Map<String, double>.from(
          (json['train_cost'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
        ),
      );
}

class SoldiersResponse {
  final List<SoldierModel> soldiers;
  final int totalAttack;
  final int totalDefense;

  SoldiersResponse({
    required this.soldiers,
    required this.totalAttack,
    required this.totalDefense,
  });

  factory SoldiersResponse.fromJson(Map<String, dynamic> json) => SoldiersResponse(
        soldiers: (json['soldiers'] as List).map((e) => SoldierModel.fromJson(e)).toList(),
        totalAttack: json['total_attack'],
        totalDefense: json['total_defense'],
      );
}
