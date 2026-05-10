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

  AllResourcesModel({
    required this.gold,
    required this.wood,
    required this.stone,
    required this.iron,
  });

  factory AllResourcesModel.fromJson(Map<String, dynamic> json) => AllResourcesModel(
        gold: ResourceState.fromJson(json['gold']),
        wood: ResourceState.fromJson(json['wood']),
        stone: ResourceState.fromJson(json['stone']),
        iron: ResourceState.fromJson(json['iron']),
      );
}
