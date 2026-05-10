import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/network/api_client.dart';
import '../../data/models/pixel_model.dart';

final mapProvider = StateNotifierProvider<MapNotifier, MapState>((ref) {
  return MapNotifier(ApiClient().dio);
});

class MapState {
  final List<PixelModel> pixels;
  final bool isLoading;
  final String? myUserId;
  final int offsetX;
  final int offsetY;

  const MapState({
    this.pixels = const [],
    this.isLoading = false,
    this.myUserId,
    this.offsetX = 0,
    this.offsetY = 0,
  });

  MapState copyWith({
    List<PixelModel>? pixels,
    bool? isLoading,
    String? myUserId,
    int? offsetX,
    int? offsetY,
  }) =>
      MapState(
        pixels: pixels ?? this.pixels,
        isLoading: isLoading ?? this.isLoading,
        myUserId: myUserId ?? this.myUserId,
        offsetX: offsetX ?? this.offsetX,
        offsetY: offsetY ?? this.offsetY,
      );
}

class MapNotifier extends StateNotifier<MapState> {
  final Dio _dio;
  final _storage = const FlutterSecureStorage();

  MapNotifier(this._dio) : super(const MapState()) {
    _loadUserId();
    loadChunk(0, 0);
  }

  Future<void> _loadUserId() async {
    // Token'dan user id çek — basit çözüm: /auth/me endpoint'i
    try {
      final res = await _dio.get('/auth/me');
      state = state.copyWith(myUserId: res.data['id']);
    } catch (_) {}
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
      final pixels = (res.data['pixels'] as List)
          .map((p) => PixelModel.fromJson(p))
          .toList();
      state = state.copyWith(pixels: pixels, isLoading: false, offsetX: x, offsetY: y);
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<String?> startBattle(int x, int y) async {
    try {
      final res = await _dio.post('/battle/start', data: {'pixel_x': x, 'pixel_y': y});
      return res.data['battle_id'];
    } catch (e) {
      return null;
    }
  }
}
