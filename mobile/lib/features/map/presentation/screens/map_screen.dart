import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/map_provider.dart';
import '../../data/models/pixel_model.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  static const int gridSize = 50;
  static const double pixelSize = 14.0;
  static const double _chunkThreshold = gridSize * pixelSize * 0.45; // ~315px

  final TransformationController _transformCtrl = TransformationController();

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  // Pan bittikten sonra yeterince kaydıysa yeni chunk yükle
  void _onInteractionEnd(ScaleEndDetails _) {
    final m = _transformCtrl.value;
    final tx = m.entry(0, 3);
    final ty = m.entry(1, 3);

    final state = ref.read(mapProvider);
    int dx = 0, dy = 0;

    if (tx < -_chunkThreshold) dx = gridSize ~/ 2;
    else if (tx > _chunkThreshold) dx = -(gridSize ~/ 2);

    if (ty < -_chunkThreshold) dy = gridSize ~/ 2;
    else if (ty > _chunkThreshold) dy = -(gridSize ~/ 2);

    if (dx != 0 || dy != 0) {
      _transformCtrl.value = Matrix4.identity();
      final newX = (state.offsetX + dx).clamp(0, 1950);
      final newY = (state.offsetY + dy).clamp(0, 1950);
      ref.read(mapProvider.notifier).loadChunk(newX, newY);
    }
  }

  void _onPixelTap(int x, int y, MapState state) {
    final owner = ref.read(mapProvider.notifier).ownerAt(x, y);
    if (owner != null && owner.userId == state.myUserId) {
      _showSnack('Bu toprak senin!', AppColors.green);
      return;
    }
    _showAttackSheet(x, y, owner, state);
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w500)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _showAttackSheet(int x, int y, TerritoryModel? owner, MapState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AttackSheet(
        x: x,
        y: y,
        owner: owner,
        onAttack: () async {
          Navigator.pop(context);
          final battleId = await ref.read(mapProvider.notifier).startBattle(x, y);
          if (battleId != null && mounted) {
            context.go('/battle/$battleId', extra: {
              'defenderUsername': owner?.username,
              'defenderPower': owner?.powerScore,
            });
          } else if (mounted) {
            _showSnack('Savaş başlatılamadı', AppColors.red);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mapProvider);

    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Column(
          children: [
            _MapHeader(
              isLoading: state.isLoading,
              onBack: () => context.go('/resources'),
            ),
            _StatsBar(state: state),
            const _MapLegend(),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Container(
                  color: const Color(0xFF0A0A14),
                  child: InteractiveViewer(
                    transformationController: _transformCtrl,
                    constrained: false,
                    minScale: 0.4,
                    maxScale: 8.0,
                    onInteractionEnd: _onInteractionEnd,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _TerritoryGrid(
                        territories: state.territories,
                        gridSize: gridSize,
                        pixelSize: pixelSize,
                        myUserId: state.myUserId,
                        offsetX: state.offsetX,
                        offsetY: state.offsetY,
                        onTap: (x, y) => _onPixelTap(x, y, state),
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

// ── Header ───────────────────────────────────────────────
class _MapHeader extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onBack;
  const _MapHeader({required this.isLoading, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
              child: const Icon(CupertinoIcons.chevron_left, color: AppColors.white, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text('Dünya Haritası',
                style: TextStyle(color: AppColors.white, fontSize: 20, fontWeight: FontWeight.w700)),
          ),
          if (isLoading)
            const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(color: AppColors.blue, strokeWidth: 2)),
        ],
      ),
    );
  }
}

// ── İstatistik Bar ───────────────────────────────────────
class _StatsBar extends StatelessWidget {
  final MapState state;
  const _StatsBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final myTerritory = state.territories.where((t) => t.userId == state.myUserId).firstOrNull;
    final myPower = myTerritory?.powerScore.toInt() ?? 0;
    final myRadius = myTerritory?.territoryRadius ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          _StatChip(icon: CupertinoIcons.bolt_fill, label: 'Gücüm', value: '$myPower', color: AppColors.yellow),
          const SizedBox(width: 10),
          _StatChip(icon: CupertinoIcons.map, label: 'Alan', value: '${myRadius * myRadius}px', color: AppColors.green),
          const SizedBox(width: 10),
          _StatChip(icon: CupertinoIcons.location, label: 'Konum',
              value: '${state.offsetX},${state.offsetY}', color: AppColors.blue),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatChip({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: AppColors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// ── Renk Açıklaması ──────────────────────────────────────
class _MapLegend extends StatelessWidget {
  const _MapLegend();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          _LegendDot(color: Colors.green, label: 'Senin'),
          const SizedBox(width: 16),
          _LegendDot(color: Colors.red, label: 'Düşman'),
          const SizedBox(width: 16),
          _LegendDot(color: const Color(0xFF0D0D1A), label: 'Boş'),
          const Spacer(),
          const Icon(CupertinoIcons.arrow_left_right, color: AppColors.textTertiary, size: 13),
          const SizedBox(width: 4),
          const Text('Kaydır = yeni bölge',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 10)),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      ],
    );
  }
}

// ── Territory Grid ───────────────────────────────────────
class _TerritoryGrid extends StatelessWidget {
  final List<TerritoryModel> territories;
  final int gridSize;
  final double pixelSize;
  final String? myUserId;
  final void Function(int x, int y) onTap;
  final int offsetX;
  final int offsetY;

  const _TerritoryGrid({
    required this.territories,
    required this.gridSize,
    required this.pixelSize,
    required this.myUserId,
    required this.onTap,
    required this.offsetX,
    required this.offsetY,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: gridSize * pixelSize,
      height: gridSize * pixelSize,
      child: CustomPaint(
        painter: _TerritoryPainter(
          territories: territories,
          gridSize: gridSize,
          pixelSize: pixelSize,
          myUserId: myUserId,
          offsetX: offsetX,
          offsetY: offsetY,
        ),
        child: GestureDetector(
          onTapDown: (details) {
            final col = (details.localPosition.dx / pixelSize).floor();
            final row = (details.localPosition.dy / pixelSize).floor();
            onTap(offsetX + col, offsetY + row);
          },
        ),
      ),
    );
  }
}

class _TerritoryPainter extends CustomPainter {
  final List<TerritoryModel> territories;
  final int gridSize;
  final double pixelSize;
  final String? myUserId;
  final int offsetX;
  final int offsetY;

  _TerritoryPainter({
    required this.territories,
    required this.gridSize,
    required this.pixelSize,
    required this.myUserId,
    required this.offsetX,
    required this.offsetY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = const Color(0xFF1C1C2E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.3;

    final bgPaint = Paint()..color = const Color(0xFF0D0D1A);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    for (final t in territories) {
      final color = t.toColor(myUserId ?? '');
      final paint = Paint()..color = color;

      final txMin = t.homeX - t.territoryRadius;
      final txMax = t.homeX + t.territoryRadius;
      final tyMin = t.homeY - t.territoryRadius;
      final tyMax = t.homeY + t.territoryRadius;

      final colStart = (txMin - offsetX).clamp(0, gridSize - 1);
      final colEnd = (txMax - offsetX).clamp(0, gridSize - 1);
      final rowStart = (tyMin - offsetY).clamp(0, gridSize - 1);
      final rowEnd = (tyMax - offsetY).clamp(0, gridSize - 1);

      for (int row = rowStart; row <= rowEnd; row++) {
        for (int col = colStart; col <= colEnd; col++) {
          final worldX = offsetX + col;
          final worldY = offsetY + row;
          if (!t.contains(worldX, worldY)) continue;

          final rect = Rect.fromLTWH(col * pixelSize, row * pixelSize, pixelSize, pixelSize);
          canvas.drawRect(rect, paint);
          canvas.drawRect(rect, borderPaint);
        }
      }

      // Merkez noktayı belirt
      final homeCol = t.homeX - offsetX;
      final homeRow = t.homeY - offsetY;
      if (homeCol >= 0 && homeCol < gridSize && homeRow >= 0 && homeRow < gridSize) {
        final centerRect = Rect.fromLTWH(
          homeCol * pixelSize + pixelSize * 0.2,
          homeRow * pixelSize + pixelSize * 0.2,
          pixelSize * 0.6,
          pixelSize * 0.6,
        );
        canvas.drawRect(centerRect, Paint()..color = Colors.white.withValues(alpha: 0.8));
      }
    }

    // Boş pikseller için grid
    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        final worldX = offsetX + col;
        final worldY = offsetY + row;
        final hasOwner = territories.any((t) => t.contains(worldX, worldY));
        if (!hasOwner) {
          final rect = Rect.fromLTWH(col * pixelSize, row * pixelSize, pixelSize, pixelSize);
          canvas.drawRect(rect, borderPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_TerritoryPainter old) =>
      old.territories != territories || old.offsetX != offsetX || old.offsetY != offsetY;
}

// ── Saldırı Bottom Sheet ─────────────────────────────────
class _AttackSheet extends StatelessWidget {
  final int x;
  final int y;
  final TerritoryModel? owner;
  final VoidCallback onAttack;

  const _AttackSheet({required this.x, required this.y, this.owner, required this.onAttack});

  @override
  Widget build(BuildContext context) {
    final isEmpty = owner == null;

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),

          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: isEmpty ? AppColors.green.withValues(alpha: 0.12) : AppColors.red.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              isEmpty ? CupertinoIcons.flag : CupertinoIcons.bolt_fill,
              color: isEmpty ? AppColors.green : AppColors.red, size: 30,
            ),
          ),

          const SizedBox(height: 16),
          Text(
            isEmpty ? 'Boş Arazi' : owner!.username,
            style: const TextStyle(color: AppColors.white, fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Konum: ($x, $y)',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),

          if (!isEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _InfoBadge(label: 'Güç', value: owner!.powerScore.toInt().toString(), color: AppColors.red),
                  _InfoBadge(label: 'Alan', value: '${owner!.territoryRadius * owner!.territoryRadius}px', color: AppColors.yellow),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isEmpty ? AppColors.green : AppColors.red,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: onAttack,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(isEmpty ? CupertinoIcons.flag_fill : CupertinoIcons.bolt_fill, size: 18),
                  const SizedBox(width: 8),
                  Text(isEmpty ? 'Toprağı Ele Geçir' : 'Saldırıya Geç',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),

          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _InfoBadge({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}
