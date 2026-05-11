import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/resources_remote_datasource.dart';
import '../../data/models/resource_model.dart';

final resourcesProvider = StateNotifierProvider<ResourcesNotifier, ResourcesState>((ref) {
  return ResourcesNotifier(ResourcesRemoteDatasource());
});

class ResourcesState {
  final AllResourcesModel? resources;
  final bool isLoading;
  final String? error;
  final Map<String, int> pendingTaps;
  final List<BuildingModel> buildings;
  final bool buildingsLoading;
  final List<SoldierModel> soldiers;
  final int totalAttack;
  final int totalDefense;
  // Tek seferlik gösterilecek offline rapor
  final Map<String, double>? offlineGainsPending;
  final double offlineSecondsPending;
  final Map<String, int>? desertionsPending;

  const ResourcesState({
    this.resources,
    this.isLoading = false,
    this.error,
    this.pendingTaps = const {},
    this.buildings = const [],
    this.buildingsLoading = false,
    this.soldiers = const [],
    this.totalAttack = 0,
    this.totalDefense = 0,
    this.offlineGainsPending,
    this.offlineSecondsPending = 0,
    this.desertionsPending,
  });

  ResourcesState copyWith({
    AllResourcesModel? resources,
    bool? isLoading,
    String? error,
    Map<String, int>? pendingTaps,
    List<BuildingModel>? buildings,
    bool? buildingsLoading,
    List<SoldierModel>? soldiers,
    int? totalAttack,
    int? totalDefense,
    Map<String, double>? offlineGainsPending,
    double? offlineSecondsPending,
    Map<String, int>? desertionsPending,
    bool clearOfflineReport = false,
  }) =>
      ResourcesState(
        resources: resources ?? this.resources,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        pendingTaps: pendingTaps ?? this.pendingTaps,
        buildings: buildings ?? this.buildings,
        buildingsLoading: buildingsLoading ?? this.buildingsLoading,
        soldiers: soldiers ?? this.soldiers,
        totalAttack: totalAttack ?? this.totalAttack,
        totalDefense: totalDefense ?? this.totalDefense,
        offlineGainsPending: clearOfflineReport
            ? null
            : (offlineGainsPending ?? this.offlineGainsPending),
        offlineSecondsPending: clearOfflineReport
            ? 0
            : (offlineSecondsPending ?? this.offlineSecondsPending),
        desertionsPending: clearOfflineReport
            ? null
            : (desertionsPending ?? this.desertionsPending),
      );
}

class ResourcesNotifier extends StateNotifier<ResourcesState> {
  final ResourcesRemoteDatasource _ds;
  Timer? _batchTimer;
  Timer? _autoTimer;

  ResourcesNotifier(this._ds) : super(const ResourcesState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    try {
      final results = await Future.wait([
        _ds.getAll(),
        _ds.getBuildings(),
        _ds.getSoldiers(),
      ]);
      final res = results[0] as AllResourcesModel;
      final buildings = results[1] as List<BuildingModel>;
      final soldiersResp = results[2] as SoldiersResponse;
      // Offline rapor sadece anlamlı miktarsa pop-up'a hak kazanır
      final hasGain = res.offlineGains.values.any((v) => v >= 1.0);
      final hasDesertion = res.desertions.values.any((v) => v > 0);
      final showReport = res.offlineSeconds >= 30 && (hasGain || hasDesertion);

      state = state.copyWith(
        resources: res,
        buildings: buildings,
        soldiers: soldiersResp.soldiers,
        totalAttack: soldiersResp.totalAttack,
        totalDefense: soldiersResp.totalDefense,
        isLoading: false,
        offlineGainsPending: showReport ? res.offlineGains : null,
        offlineSecondsPending: showReport ? res.offlineSeconds : 0,
        desertionsPending: showReport ? res.desertions : null,
      );
      _startAutoProduction();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void tap(String resourceType) {
    if (state.resources == null) return;

    final pending = Map<String, int>.from(state.pendingTaps);
    pending[resourceType] = (pending[resourceType] ?? 0) + 1;

    final tapPower = _getTapPower(resourceType);
    final updated = _addAmount(state.resources!, resourceType, tapPower.toDouble());
    state = state.copyWith(resources: updated, pendingTaps: pending);

    _batchTimer?.cancel();
    _batchTimer = Timer(const Duration(milliseconds: 500), _flushTaps);
  }

  Future<void> _flushTaps() async {
    final pending = Map<String, int>.from(state.pendingTaps);
    if (pending.isEmpty) return;
    state = state.copyWith(pendingTaps: {});
    for (final entry in pending.entries) {
      try {
        final result = await _ds.tap(entry.key, entry.value);
        // Sunucunun gerçek miktarıyla lokali düzelt
        final serverTotal = (result['total'] as num?)?.toDouble();
        if (serverTotal != null && state.resources != null) {
          state = state.copyWith(
            resources: _setAmount(state.resources!, entry.key, serverTotal),
          );
        }
      } catch (_) {}
    }
  }

  Future<void> upgradeTap(String resourceType) async {
    try {
      await _ds.upgradeTap(resourceType);
      await load();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> buildOrUpgrade(String buildingType) async {
    _batchTimer?.cancel();
    await _flushTaps();
    state = state.copyWith(buildingsLoading: true);
    try {
      await _ds.buildOrUpgrade(buildingType);
      await load();
    } catch (e) {
      state = state.copyWith(buildingsLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> trainSoldiers(String soldierType, int amount) async {
    _batchTimer?.cancel();
    await _flushTaps();
    state = state.copyWith(buildingsLoading: true);
    try {
      await _ds.trainSoldiers(soldierType, amount);
      await load();
    } catch (e) {
      state = state.copyWith(buildingsLoading: false, error: e.toString());
      rethrow;
    }
  }

  static const Map<String, double> _foodDrainPerType = {
    'swordsman': 0.01,
    'archer': 0.02,
    'knight': 0.06,
    'catapult': 0.10,
  };

  void _startAutoProduction() {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.resources == null) return;
      var r = state.resources!;
      if (r.gold.autoRate > 0) r = _addAmount(r, 'gold', r.gold.autoRate);
      if (r.wood.autoRate > 0) r = _addAmount(r, 'wood', r.wood.autoRate);
      if (r.stone.autoRate > 0) r = _addAmount(r, 'stone', r.stone.autoRate);
      if (r.iron.autoRate > 0) r = _addAmount(r, 'iron', r.iron.autoRate);
      if (r.food.autoRate > 0) r = _addAmount(r, 'food', r.food.autoRate);

      // Food tüketimi: asker tipine göre
      final foodDrain = state.soldiers.fold<double>(
        0,
        (sum, s) => sum + s.count * (_foodDrainPerType[s.soldierType] ?? 0.0),
      );
      if (foodDrain > 0) r = _addAmount(r, 'food', -foodDrain);

      state = state.copyWith(resources: r);
    });
  }

  /// Offline raporu UI bir kez gösterdikten sonra temizler
  void clearOfflineReport() {
    state = state.copyWith(clearOfflineReport: true);
  }

  int _getTapPower(String type) {
    final r = state.resources;
    if (r == null) return 1;
    switch (type) {
      case 'gold': return r.gold.tapPower;
      case 'wood': return r.wood.tapPower;
      case 'stone': return r.stone.tapPower;
      case 'iron': return r.iron.tapPower;
      case 'food': return r.food.tapPower;
      default: return 1;
    }
  }

  AllResourcesModel _setAmount(AllResourcesModel r, String type, double amount) {
    ResourceState setVal(ResourceState s) =>
        s.copyWith(amount: amount, isCapped: amount >= s.storageCap - 1e-3);

    return AllResourcesModel(
      gold: type == 'gold' ? setVal(r.gold) : r.gold,
      wood: type == 'wood' ? setVal(r.wood) : r.wood,
      stone: type == 'stone' ? setVal(r.stone) : r.stone,
      iron: type == 'iron' ? setVal(r.iron) : r.iron,
      food: type == 'food' ? setVal(r.food) : r.food,
      offlineGains: r.offlineGains,
      offlineSeconds: r.offlineSeconds,
      desertions: r.desertions,
    );
  }

  AllResourcesModel _addAmount(AllResourcesModel r, String type, double amount) {
    ResourceState bump(ResourceState s) {
      final next = (s.amount + amount).clamp(0, s.storageCap);
      return s.copyWith(amount: next.toDouble(), isCapped: next >= s.storageCap - 1e-3);
    }

    return AllResourcesModel(
      gold: type == 'gold' ? bump(r.gold) : r.gold,
      wood: type == 'wood' ? bump(r.wood) : r.wood,
      stone: type == 'stone' ? bump(r.stone) : r.stone,
      iron: type == 'iron' ? bump(r.iron) : r.iron,
      food: type == 'food' ? bump(r.food) : r.food,
      offlineGains: r.offlineGains,
      offlineSeconds: r.offlineSeconds,
      desertions: r.desertions,
    );
  }

  @override
  void dispose() {
    _batchTimer?.cancel();
    _autoTimer?.cancel();
    super.dispose();
  }
}
