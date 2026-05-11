import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/app_constants.dart';

final battleProvider = StateNotifierProvider.family<BattleNotifier, BattleState, String>(
  (ref, battleId) => BattleNotifier(ApiClient().dio, battleId),
);

class DamageBreakdown {
  final double totalDamage;
  final double damageRatio;
  final double resourcesLost;
  final int soldiersLost;
  final bool buildingDegraded;
  final int pixelsTransferred;
  final bool defenderEliminated;

  const DamageBreakdown({
    required this.totalDamage,
    required this.damageRatio,
    required this.resourcesLost,
    required this.soldiersLost,
    required this.buildingDegraded,
    required this.pixelsTransferred,
    required this.defenderEliminated,
  });

  factory DamageBreakdown.fromJson(Map<String, dynamic> j) => DamageBreakdown(
        totalDamage: (j['total_damage'] as num).toDouble(),
        damageRatio: (j['damage_ratio'] as num).toDouble(),
        resourcesLost: (j['resources_lost'] as num).toDouble(),
        soldiersLost: (j['soldiers_lost'] as num? ?? 0).toInt(),
        buildingDegraded: j['building_degraded'] as bool? ?? false,
        pixelsTransferred: (j['pixels_transferred'] as num? ?? 0).toInt(),
        defenderEliminated: j['defender_eliminated'] as bool? ?? false,
      );
}

class BattleState {
  final int myTaps;
  final int enemyTaps;
  final int remainingSeconds;
  final bool isFinished;
  final bool? won;
  final bool pixelCaptured;
  final DamageBreakdown? damage;
  final String? defenderUsername;
  final double? defenderPower;
  final double? attackerPower;

  const BattleState({
    this.myTaps = 0,
    this.enemyTaps = 0,
    this.remainingSeconds = AppConstants.battleDurationSeconds,
    this.isFinished = false,
    this.won,
    this.pixelCaptured = false,
    this.damage,
    this.defenderUsername,
    this.defenderPower,
    this.attackerPower,
  });

  BattleState copyWith({
    int? myTaps,
    int? enemyTaps,
    int? remainingSeconds,
    bool? isFinished,
    bool? won,
    bool? pixelCaptured,
    DamageBreakdown? damage,
    String? defenderUsername,
    double? defenderPower,
    double? attackerPower,
  }) =>
      BattleState(
        myTaps: myTaps ?? this.myTaps,
        enemyTaps: enemyTaps ?? this.enemyTaps,
        remainingSeconds: remainingSeconds ?? this.remainingSeconds,
        isFinished: isFinished ?? this.isFinished,
        won: won ?? this.won,
        pixelCaptured: pixelCaptured ?? this.pixelCaptured,
        damage: damage ?? this.damage,
        defenderUsername: defenderUsername ?? this.defenderUsername,
        defenderPower: defenderPower ?? this.defenderPower,
        attackerPower: attackerPower ?? this.attackerPower,
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
      final data = res.data as Map<String, dynamic>;
      final won = data['winner_id'] != null;
      final dmgJson = data['damage'] as Map<String, dynamic>?;
      state = state.copyWith(
        isFinished: true,
        won: won,
        pixelCaptured: data['pixel_captured'] ?? false,
        damage: dmgJson != null ? DamageBreakdown.fromJson(dmgJson) : null,
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
