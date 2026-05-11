import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/battle_provider.dart';
import '../../../resources/presentation/providers/resources_provider.dart';

class BattleScreen extends ConsumerStatefulWidget {
  final String battleId;
  final String? defenderUsername;
  final double? defenderPower;

  const BattleScreen({
    super.key,
    required this.battleId,
    this.defenderUsername,
    this.defenderPower,
  });

  @override
  ConsumerState<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends ConsumerState<BattleScreen>
    with TickerProviderStateMixin {
  late AnimationController _tapAnim;
  late AnimationController _pulseAnim;

  @override
  void initState() {
    super.initState();
    _tapAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 80));
    _pulseAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _tapAnim.dispose();
    _pulseAnim.dispose();
    super.dispose();
  }

  void _onTap() {
    ref.read(battleProvider(widget.battleId).notifier).tap();
    _tapAnim.forward().then((_) => _tapAnim.reverse());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(battleProvider(widget.battleId));
    final resourcesState = ref.watch(resourcesProvider);

    if (state.isFinished) {
      return _ResultScreen(
        state: state,
        defenderUsername: widget.defenderUsername,
      );
    }

    final total = state.myTaps + state.enemyTaps;
    final myRatio = total == 0 ? 0.5 : state.myTaps / total;
    final timeRatio = state.remainingSeconds / 30.0;

    final timerColor = state.remainingSeconds > 15
        ? AppColors.green
        : state.remainingSeconds > 7
            ? AppColors.yellow
            : AppColors.red;

    // Power comparison
    final myPower = resourcesState.resources != null
        ? _calcDisplayPower(resourcesState)
        : null;
    final defPower = widget.defenderPower;

    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Column(
          children: [
            _TimerSection(
              seconds: state.remainingSeconds,
              ratio: timeRatio,
              color: timerColor,
              defenderUsername: widget.defenderUsername,
            ),

            const SizedBox(height: 16),

            // Power comparison bar
            if (myPower != null && defPower != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _PowerComparisonBar(
                  myPower: myPower,
                  defenderPower: defPower,
                ),
              ),

            const SizedBox(height: 16),

            // Tap scores
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  _ScoreCard(
                    label: 'Sen',
                    taps: state.myTaps,
                    color: AppColors.blue,
                    isLeading: state.myTaps >= state.enemyTaps,
                  ),
                  const SizedBox(width: 12),
                  _ScoreCard(
                    label: widget.defenderUsername ?? 'Düşman',
                    taps: state.enemyTaps,
                    color: AppColors.red,
                    isLeading: state.enemyTaps > state.myTaps,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Tap ratio bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _TapBar(myRatio: myRatio),
            ),

            const SizedBox(height: 8),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sen  ${(myRatio * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                        color: AppColors.blue,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${((1 - myRatio) * 100).toStringAsFixed(0)}%  Düşman',
                    style: const TextStyle(
                        color: AppColors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: GestureDetector(
                  onTapDown: (_) => _onTap(),
                  child: ScaleTransition(
                    scale: Tween(begin: 1.0, end: 0.95).animate(
                      CurvedAnimation(parent: _tapAnim, curve: Curves.easeOut),
                    ),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppColors.blue.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _pulseAnim,
                            builder: (_, __) => Transform.scale(
                              scale: 1.0 + _pulseAnim.value * 0.06,
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.blue.withOpacity(
                                      0.08 + _pulseAnim.value * 0.06),
                                  border: Border.all(
                                    color: AppColors.blue.withOpacity(
                                        0.3 + _pulseAnim.value * 0.2),
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  CupertinoIcons.hand_point_left_fill,
                                  color: AppColors.blue,
                                  size: 48,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          Text(
                            '${state.myTaps}',
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 56,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                            ),
                          ),

                          const SizedBox(height: 4),

                          const Text(
                            'DOKUN VE KAZAN',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _calcDisplayPower(ResourcesState s) {
    // Simplified attacker power for display: soldiers + buildings contribution
    final buildScore = s.buildings.fold<double>(0, (acc, b) => acc + b.level * 2.0);
    final soldierScore = s.totalAttack.toDouble();
    return buildScore * 0.30 + soldierScore * 0.70;
  }
}

// ── Power Comparison Bar ─────────────────────────────────
class _PowerComparisonBar extends StatelessWidget {
  final double myPower;
  final double defenderPower;

  const _PowerComparisonBar({
    required this.myPower,
    required this.defenderPower,
  });

  String _fmt(double v) {
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final total = myPower + defenderPower;
    final myRatio = total == 0 ? 0.5 : (myPower / total).clamp(0.05, 0.95);
    final stronger = myPower >= defenderPower;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(CupertinoIcons.bolt_fill,
                      color: AppColors.blue, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Sen  ${_fmt(myPower)}',
                    style: TextStyle(
                      color: stronger ? AppColors.blue : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    '${_fmt(defenderPower)}  Def',
                    style: TextStyle(
                      color: !stronger ? AppColors.red : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(CupertinoIcons.shield_fill,
                      color: AppColors.red, size: 14),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Container(color: AppColors.red.withOpacity(0.7)),
                  FractionallySizedBox(
                    widthFactor: myRatio,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.blue,
                            stronger ? AppColors.green : AppColors.blue,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            stronger
                ? 'Güç avantajın var — daha az tab yeterli!'
                : 'Düşman güçlü — daha fazla tab gerekli!',
            style: TextStyle(
              color: stronger ? AppColors.green : AppColors.yellow,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Timer ─────────────────────────────────────────────────
class _TimerSection extends StatelessWidget {
  final int seconds;
  final double ratio;
  final Color color;
  final String? defenderUsername;

  const _TimerSection({
    required this.seconds,
    required this.ratio,
    required this.color,
    this.defenderUsername,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SAVAŞ',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                    ),
                  ),
                  if (defenderUsername != null)
                    Text(
                      defenderUsername!,
                      style: const TextStyle(
                        color: AppColors.red,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.timer, color: color, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      '${seconds}s',
                      style: TextStyle(
                        color: color,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: AppColors.surface,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Skor Kartı ────────────────────────────────────────────
class _ScoreCard extends StatelessWidget {
  final String label;
  final int taps;
  final Color color;
  final bool isLeading;

  const _ScoreCard({
    required this.label,
    required this.taps,
    required this.color,
    required this.isLeading,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isLeading ? color.withOpacity(0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLeading ? color.withOpacity(0.4) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isLeading ? color : AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isLeading) ...[
                  const SizedBox(width: 4),
                  Icon(CupertinoIcons.arrow_up, color: color, size: 12),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '$taps',
              style: TextStyle(
                color: isLeading ? color : AppColors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'dokunuş',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab Oranı Barı ────────────────────────────────────────
class _TapBar extends StatelessWidget {
  final double myRatio;
  const _TapBar({required this.myRatio});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 10,
        child: Stack(
          children: [
            Container(color: AppColors.red),
            FractionallySizedBox(
              widthFactor: myRatio,
              child: Container(color: AppColors.blue),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sonuç Ekranı ──────────────────────────────────────────
class _ResultScreen extends StatelessWidget {
  final BattleState state;
  final String? defenderUsername;

  const _ResultScreen({required this.state, this.defenderUsername});

  String _outcomeText() {
    final d = state.damage;
    if (d == null) {
      return state.won == true
          ? (state.pixelCaptured ? 'Toprak ele geçirildi!' : 'Rakibi geçtim!')
          : 'Daha sert tıkla!';
    }
    if (d.defenderEliminated) return 'Düşman tamamen silindi!';
    if (d.damageRatio >= 0.5) return 'Büyük zafer! Toprak alındı.';
    if (d.damageRatio >= 0.2) return 'Kısmi zafer. Kaynaklar ele geçirildi.';
    return 'Saldırı püskürtüldü!';
  }

  @override
  Widget build(BuildContext context) {
    final won = state.won ?? false;
    final color = won ? AppColors.green : AppColors.red;
    final d = state.damage;

    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 24),

              // Sonuç ikonu
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.4), width: 2),
                ),
                child: Icon(
                  won ? CupertinoIcons.checkmark_alt : CupertinoIcons.xmark,
                  color: color,
                  size: 48,
                ),
              ),

              const SizedBox(height: 20),

              Text(
                won ? 'Zafer!' : 'Yenildin',
                style: TextStyle(
                  color: color,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                _outcomeText(),
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 15),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 28),

              // Tab karşılaştırma
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    _ResultStat(
                      label: 'Senin',
                      value: '${state.myTaps}',
                      color: AppColors.blue,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          const Text('VS',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16)),
                          const SizedBox(height: 4),
                          const Text('dokunuş',
                              style: TextStyle(
                                  color: AppColors.textSecondary, fontSize: 11)),
                        ],
                      ),
                    ),
                    _ResultStat(
                      label: defenderUsername ?? 'Düşman',
                      value: '${state.enemyTaps}',
                      color: AppColors.red,
                    ),
                  ],
                ),
              ),

              // Hasar breakdown (sadece kazandıysa ve data varsa)
              if (d != null) ...[
                const SizedBox(height: 16),
                _DamageBreakdownCard(damage: d),
              ],

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => context.go('/map'),
                  child: const Text(
                    'Haritaya Dön',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: TextButton(
                  onPressed: () => context.go('/resources'),
                  child: const Text(
                    'Ana Sayfaya Dön',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 16),
                  ),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Hasar Detay Kartı ─────────────────────────────────────
class _DamageBreakdownCard extends StatelessWidget {
  final DamageBreakdown damage;
  const _DamageBreakdownCard({required this.damage});

  String _fmt(double v) {
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  Color _ratioColor() {
    if (damage.damageRatio >= 0.9) return AppColors.red;
    if (damage.damageRatio >= 0.5) return AppColors.yellow;
    if (damage.damageRatio >= 0.2) return AppColors.green;
    return AppColors.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surface3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'HASAR DETAYI',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 14),

          // Damage ratio bar
          Row(
            children: [
              const Text('Hasar Oranı',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const Spacer(),
              Text(
                '${(damage.damageRatio * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  color: _ratioColor(),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: damage.damageRatio.clamp(0.0, 1.0),
              backgroundColor: AppColors.surface3,
              valueColor: AlwaysStoppedAnimation(_ratioColor()),
              minHeight: 6,
            ),
          ),

          const SizedBox(height: 14),
          const Divider(color: AppColors.surface3, height: 1),
          const SizedBox(height: 14),

          // Stats grid
          Row(
            children: [
              _BreakdownStat(
                icon: '💰',
                label: 'Kaynak Kaybı',
                value: _fmt(damage.resourcesLost),
                color: AppColors.yellow,
              ),
              _BreakdownStat(
                icon: '⚔️',
                label: 'Asker Kaybı',
                value: '${damage.soldiersLost}',
                color: AppColors.red,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _BreakdownStat(
                icon: '🏰',
                label: 'Bina Hasarı',
                value: damage.buildingDegraded ? 'Evet' : 'Hayır',
                color: damage.buildingDegraded
                    ? AppColors.red
                    : AppColors.textSecondary,
              ),
              _BreakdownStat(
                icon: '🗺️',
                label: 'Toprak Ele Geçirildi',
                value: '${damage.pixelsTransferred}px',
                color: damage.pixelsTransferred > 0
                    ? AppColors.green
                    : AppColors.textSecondary,
              ),
            ],
          ),

          if (damage.defenderEliminated) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.red.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.red.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.xmark_circle_fill,
                      color: AppColors.red, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Düşman tamamen yok edildi!',
                    style: TextStyle(
                      color: AppColors.red,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BreakdownStat extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final Color color;

  const _BreakdownStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: AppColors.black,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                  color: AppColors.textTertiary, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ResultStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 36,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13)),
      ],
    );
  }
}
