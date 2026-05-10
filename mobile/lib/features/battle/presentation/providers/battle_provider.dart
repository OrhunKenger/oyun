import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/app_constants.dart';

final battleProvider = StateNotifierProvider.family<BattleNotifier, BattleState, String>(
  (ref, battleId) => BattleNotifier(ApiClient().dio, battleId),
);

class BattleState {
  final int myTaps;
  final int enemyTaps;
  final int remainingSeconds;
  final bool isFinished;
  final bool? won;
  final bool pixelCaptured;

  const BattleState({
    this.myTaps = 0,
    this.enemyTaps = 0,
    this.remainingSeconds = AppConstants.battleDurationSeconds,
    this.isFinished = false,
    this.won,
    this.pixelCaptured = false,
  });

  BattleState copyWith({
    int? myTaps,
    int? enemyTaps,
    int? remainingSeconds,
    bool? isFinished,
    bool? won,
    bool? pixelCaptured,
  }) =>
      BattleState(
        myTaps: myTaps ?? this.myTaps,
        enemyTaps: enemyTaps ?? this.enemyTaps,
        remainingSeconds: remainingSeconds ?? this.remainingSeconds,
        isFinished: isFinished ?? this.isFinished,
        won: won ?? this.won,
        pixelCaptured: pixelCaptured ?? this.pixelCaptured,
      );
}

class BattleNotifier extends StateNotifier<BattleState> {
  final Dio _dio;
  final String battleId;
  Timer? _timer;
  Timer? _flushTimer;
  int _pendingTaps = 0;

  BattleNotifier(this._dio, this.battleId) : super(const BattleState()) {
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      final remaining = state.remainingSeconds - 1;
      if (remaining <= 0) {
        t.cancel();
        _finish();
      } else {
        state = state.copyWith(remainingSeconds: remaining);
      }
    });
  }

  void tap() {
    if (state.isFinished) return;
    _pendingTaps++;
    state = state.copyWith(myTaps: state.myTaps + 1);

    _flushTimer?.cancel();
    _flushTimer = Timer(const Duration(milliseconds: 300), _flushTaps);
  }

  Future<void> _flushTaps() async {
    if (_pendingTaps == 0) return;
    final count = _pendingTaps;
    _pendingTaps = 0;
    try {
      final res = await _dio.post('/battle/tap', data: {
        'battle_id': battleId,
        'tap_count': count,
      });
      state = state.copyWith(
        enemyTaps: res.data['defender_taps'] ?? state.enemyTaps,
      );
    } catch (_) {}
  }

  Future<void> _finish() async {
    await _flushTaps();
    try {
      final res = await _dio.post('/battle/$battleId/finish');
      final won = res.data['winner_id'] != null;
      state = state.copyWith(
        isFinished: true,
        won: won,
        pixelCaptured: res.data['pixel_captured'] ?? false,
      );
    } catch (_) {
      state = state.copyWith(isFinished: true, won: state.myTaps > state.enemyTaps);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _flushTimer?.cancel();
    super.dispose();
  }
}
