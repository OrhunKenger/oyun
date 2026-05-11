import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/battle_provider.dart';

class BattleScreen extends ConsumerStatefulWidget {
  final String battleId;
  const BattleScreen({super.key, required this.battleId});

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

    if (state.isFinished) {
      return _ResultScreen(state: state);
    }

    final total = state.myTaps + state.enemyTaps;
    final myRatio = total == 0 ? 0.5 : state.myTaps / total;
    final timeRatio = state.remainingSeconds / 30.0;

    final timerColor = state.remainingSeconds > 15
        ? AppColors.green
        : state.remainingSeconds > 7
            ? AppColors.yellow
            : AppColors.red;

    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ── Timer ──────────────────────────────────
            _TimerSection(
              seconds: state.remainingSeconds,
              ratio: timeRatio,
              color: timerColor,
            ),

            const SizedBox(height: 20),

            // ── Skorlar ────────────────────────────────
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
                    label: 'Düşman',
                    taps: state.enemyTaps,
                    color: AppColors.red,
                    isLeading: state.enemyTaps > state.myTaps,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Güç barı ───────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _PowerBar(myRatio: myRatio),
            ),

            const SizedBox(height: 12),

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

            // ── Ana Tıklama Alanı ──────────────────────
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
                          // Nabız animasyonu
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
}

// ── Timer ─────────────────────────────────────────────────
class _TimerSection extends StatelessWidget {
  final int seconds;
  final double ratio;
  final Color color;

  const _TimerSection({
    required this.seconds,
    required this.ratio,
    required this.color,
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
              const Text(
                'SAVAŞ',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
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
                Text(
                  label,
                  style: TextStyle(
                    color: isLeading ? color : AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isLeading) ...[
                  const SizedBox(width: 6),
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

// ── Güç Barı ──────────────────────────────────────────────
class _PowerBar extends StatelessWidget {
  final double myRatio;
  const _PowerBar({required this.myRatio});

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
  const _ResultScreen({required this.state});

  @override
  Widget build(BuildContext context) {
    final won = state.won ?? false;
    final color = won ? AppColors.green : AppColors.red;

    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),

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

              const SizedBox(height: 24),

              Text(
                won ? 'Zafer!' : 'Yenildin',
                style: TextStyle(
                  color: color,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                won && state.pixelCaptured
                    ? 'Piksel senin kontrolünde!'
                    : won
                        ? 'Rakibi geçtim!'
                        : 'Daha sert tıkla!',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 16),
              ),

              const SizedBox(height: 40),

              // Skor karşılaştırma
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
                      label: 'Düşman',
                      value: '${state.enemyTaps}',
                      color: AppColors.red,
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Butonlar
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: color),
                onPressed: () => context.go('/map'),
                child: const Text('Haritaya Dön'),
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
