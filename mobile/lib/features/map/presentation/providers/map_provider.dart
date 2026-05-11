import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/models/pixel_model.dart';

final mapProvider = StateNotifierProvider<MapNotifier, MapState>((ref) {
  return MapNotifier(ApiClient().dio);
});

class MapState {
  final List<TerritoryModel> territories;
  final bool isLoading;
  final String? myUserId;
  final int? myHomeX;
  final int? myHomeY;
  final int offsetX;
  final int offsetY;

  const MapState({
    this.territories = const [],
    this.isLoading = false,
    this.myUserId,
    this.myHomeX,
    this.myHomeY,
    this.offsetX = 0,
    this.offsetY = 0,
  });

  MapState copyWith({
    List<TerritoryModel>? territories,
    bool? isLoading,
    String? myUserId,
    int? myHomeX,
    int? myHomeY,
    int? offsetX,
    int? offsetY,
  }) =>
      MapState(
        territories: territories ?? this.territories,
        isLoading: isLoading ?? this.isLoading,
        myUserId: myUserId ?? this.myUserId,
        myHomeX: myHomeX ?? this.myHomeX,
        myHomeY: myHomeY ?? this.myHomeY,
        offsetX: offsetX ?? this.offsetX,
        offsetY: offsetY ?? this.offsetY,
      );
}

class MapNotifier extends StateNotifier<MapState> {
  final Dio _dio;

  MapNotifier(this._dio) : super(const MapState()) {
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final res = await _dio.get('/auth/me');
      final homeX = res.data['home_x'] as int?;
      final homeY = res.data['home_y'] as int?;
      state = state.copyWith(
        myUserId: res.data['id'],
        myHomeX: homeX,
        myHomeY: homeY,
      );
      // Home varsa oradan başla, yoksa (0,0)
      if (homeX != null && homeY != null) {
        final startX = (homeX - 25).clamp(0, 1950);
        final startY = (homeY - 25).clamp(0, 1950);
        await loadChunk(startX, startY);
      } else {
        await loadChunk(0, 0);
      }
    } catch (_) {
      await loadChunk(0, 0);
    }
  }

  Future<void> loadChunk(int x, int y) async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await _dio.get('/map/chunk', queryParameters: {
        'x_start': x,
        'y_start': y,
        'width': 50,
        'height': 50,
      });
      final players = (res.data['players'] as List)
          .map((p) => TerritoryModel.fromJson(p))
          .toList();
      state = state.copyWith(territories: players, isLoading: false, offsetX: x, offsetY: y);
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> goHome() async {
    final hx = state.myHomeX;
    final hy = state.myHomeY;
    if (hx == null || hy == null) return;
    final startX = (hx - 25).clamp(0, 1950);
    final startY = (hy - 25).clamp(0, 1950);
    await loadChunk(startX, startY);
  }

  Future<String?> startBattle(int x, int y) async {
    try {
      final res = await _dio.post('/battle/start', data: {'pixel_x': x, 'pixel_y': y});
      return res.data['battle_id'];
    } catch (e) {
      return null;
    }
  }

  TerritoryModel? ownerAt(int x, int y) {
    for (final t in state.territories) {
      if (t.contains(x, y)) return t;
    }
    return null;
  }
}
