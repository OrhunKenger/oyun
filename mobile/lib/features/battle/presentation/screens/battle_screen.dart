import 'package:flutter/material.dart';
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

class _BattleScreenState extends ConsumerState<BattleScreen> with TickerProviderStateMixin {
  late AnimationController _tapAnim;
  late AnimationController _shakeAnim;

  @override
  void initState() {
    super.initState();
    _tapAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 60));
    _shakeAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  }

  @override
  void dispose() {
    _tapAnim.dispose();
    _shakeAnim.dispose();
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
      return _ResultScreen(state: state, battleId: widget.battleId);
    }

    final total = state.myTaps + state.enemyTaps;
    final myRatio = total == 0 ? 0.5 : state.myTaps / total;
    final progress = state.remainingSeconds / 30.0;

    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: SafeArea(
        child: Column(
          children: [
            // Süre bar
            _TimerBar(progress: progress, seconds: state.remainingSeconds),
            const SizedBox(height: 16),
            // Skor
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _ScoreBox(label: 'SEN', taps: state.myTaps, color: const Color(0xFF00FF88)),
                  const Text('VS', style: TextStyle(color: Colors.white54, fontSize: 20, fontWeight: FontWeight.bold)),
                  _ScoreBox(label: 'DÜŞMAN', taps: state.enemyTaps, color: AppTheme.accent, align: TextAlign.right),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Güç barı
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _PowerBar(myRatio: myRatio),
            ),
            const SizedBox(height: 24),
            const Text(
              'EKRANA VURARAK KAZANMAYA ÇALIŞ!',
              style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 3),
            ),
            // Ana tıklama alanı
            Expanded(
              child: GestureDetector(
                onTapDown: (_) => _onTap(),
                child: ScaleTransition(
                  scale: Tween(begin: 1.0, end: 0.96).animate(
                    CurvedAnimation(parent: _tapAnim, curve: Curves.easeOut),
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const RadialGradient(
                        colors: [Color(0xFF16213E), Color(0xFF0A0A1A)],
                      ),
                      border: Border.all(color: AppTheme.accent, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('⚔️', style: TextStyle(fontSize: 80)),
                          const SizedBox(height: 16),
                          Text(
                            '${state.myTaps}',
                            style: const TextStyle(
                              fontSize: 64,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00FF88),
                            ),
                          ),
                          const Text(
                            'TAP',
                            style: TextStyle(color: Colors.white38, fontSize: 14, letterSpacing: 6),
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

class _TimerBar extends StatelessWidget {
  final double progress;
  final int seconds;

  const _TimerBar({required this.progress, required this.seconds});

  @override
  Widget build(BuildContext context) {
    final color = progress > 0.5
        ? const Color(0xFF00FF88)
        : progress > 0.25
            ? AppTheme.gold
            : AppTheme.accent;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('SÜRE', style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 3)),
              Text('${seconds}s', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: AppTheme.secondary,
          valueColor: AlwaysStoppedAnimation(color),
          minHeight: 4,
        ),
      ],
    );
  }
}

class _ScoreBox extends StatelessWidget {
  final String label;
  final int taps;
  final Color color;
  final TextAlign align;

  const _ScoreBox({
    required this.label,
    required this.taps,
    required this.color,
    this.align = TextAlign.left,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          align == TextAlign.right ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 2)),
        Text(
          '$taps',
          style: TextStyle(color: color, fontSize: 32, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _PowerBar extends StatelessWidget {
  final double myRatio;
  const _PowerBar({required this.myRatio});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('GÜÇ ORANI', style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 3)),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 16,
            child: Stack(
              children: [
                Container(color: AppTheme.accent),
                FractionallySizedBox(
                  widthFactor: myRatio,
                  child: Container(color: const Color(0xFF00FF88)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ResultScreen extends StatelessWidget {
  final BattleState state;
  final String battleId;

  const _ResultScreen({required this.state, required this.battleId});

  @override
  Widget build(BuildContext context) {
    final won = state.won ?? false;

    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                won ? '🏆' : '💀',
                style: const TextStyle(fontSize: 80),
              ),
              const SizedBox(height: 16),
              Text(
                won ? 'ZAFER!' : 'YENILDIN',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: won ? const Color(0xFF00FF88) : AppTheme.accent,
                  letterSpacing: 6,
                ),
              ),
              const SizedBox(height: 8),
              if (won && state.pixelCaptured)
                const Text(
                  'Piksel senin!',
                  style: TextStyle(color: Color(0xFF00FF88), fontSize: 16),
                ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StatBox(label: 'SENİN TAPLAR', value: '${state.myTaps}', color: const Color(0xFF00FF88)),
                  const SizedBox(width: 32),
                  _StatBox(label: 'DÜŞMAN TAPLAR', value: '${state.enemyTaps}', color: AppTheme.accent),
                ],
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                onPressed: () => context.go('/map'),
                child: const Text('HARİTAYA DÖN', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/resources'),
                child: const Text('ANA EKRANA DÖN', style: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1)),
        Text(value, style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
