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

  const ResourcesState({
    this.resources,
    this.isLoading = false,
    this.error,
    this.pendingTaps = const {},
    this.buildings = const [],
    this.buildingsLoading = false,
  });

  ResourcesState copyWith({
    AllResourcesModel? resources,
    bool? isLoading,
    String? error,
    Map<String, int>? pendingTaps,
    List<BuildingModel>? buildings,
    bool? buildingsLoading,
  }) =>
      ResourcesState(
        resources: resources ?? this.resources,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        pendingTaps: pendingTaps ?? this.pendingTaps,
        buildings: buildings ?? this.buildings,
        buildingsLoading: buildingsLoading ?? this.buildingsLoading,
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
      ]);
      final res = results[0] as AllResourcesModel;
      final buildings = results[1] as List<BuildingModel>;
      state = state.copyWith(resources: res, buildings: buildings, isLoading: false);
      _startAutoProduction();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // Tıklamayı anında UI'a yansıt, batch olarak sunucuya gönder
  void tap(String resourceType) {
    if (state.resources == null) return;

    final pending = Map<String, int>.from(state.pendingTaps);
    pending[resourceType] = (pending[resourceType] ?? 0) + 1;

    // Anlık UI güncellemesi
    final tapPower = _getTapPower(resourceType);
    final updated = _addAmount(state.resources!, resourceType, tapPower.toDouble());
    state = state.copyWith(resources: updated, pendingTaps: pending);

    // 500ms sonra batch gönder
    _batchTimer?.cancel();
    _batchTimer = Timer(const Duration(milliseconds: 500), _flushTaps);
  }

  Future<void> _flushTaps() async {
    final pending = Map<String, int>.from(state.pendingTaps);
    if (pending.isEmpty) return;
    state = state.copyWith(pendingTaps: {});

    for (final entry in pending.entries) {
      try {
        await _ds.tap(entry.key, entry.value);
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
    state = state.copyWith(buildingsLoading: true);
    try {
      await _ds.buildOrUpgrade(buildingType);
      await load();
    } catch (e) {
      state = state.copyWith(buildingsLoading: false, error: e.toString());
      rethrow;
    }
  }

  void _startAutoProduction() {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.resources == null) return;
      var r = state.resources!;
      if (r.gold.autoRate > 0) r = _addAmount(r, 'gold', r.gold.autoRate);
      if (r.wood.autoRate > 0) r = _addAmount(r, 'wood', r.wood.autoRate);
      if (r.stone.autoRate > 0) r = _addAmount(r, 'stone', r.stone.autoRate);
      if (r.iron.autoRate > 0) r = _addAmount(r, 'iron', r.iron.autoRate);
      state = state.copyWith(resources: r);
    });
  }

  int _getTapPower(String type) {
    final r = state.resources;
    if (r == null) return 1;
    switch (type) {
      case 'gold': return r.gold.tapPower;
      case 'wood': return r.wood.tapPower;
      case 'stone': return r.stone.tapPower;
      case 'iron': return r.iron.tapPower;
      default: return 1;
    }
  }

  AllResourcesModel _addAmount(AllResourcesModel r, String type, double amount) {
    return AllResourcesModel(
      gold: type == 'gold' ? r.gold.copyWith(amount: r.gold.amount + amount) : r.gold,
      wood: type == 'wood' ? r.wood.copyWith(amount: r.wood.amount + amount) : r.wood,
      stone: type == 'stone' ? r.stone.copyWith(amount: r.stone.amount + amount) : r.stone,
      iron: type == 'iron' ? r.iron.copyWith(amount: r.iron.amount + amount) : r.iron,
    );
  }

  @override
  void dispose() {
    _batchTimer?.cancel();
    _autoTimer?.cancel();
    super.dispose();
  }
}
