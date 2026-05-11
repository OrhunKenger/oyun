import 'dart:math' as math;
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
  final TransformationController _transformCtrl = TransformationController();
  PixelModel? _selected;

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  void _onPixelTap(PixelModel pixel, MapState state) {
    if (pixel.ownerId == state.myUserId) {
      _showSnack('Bu piksel zaten senin!', AppColors.green);
      return;
    }
    setState(() => _selected = pixel);
    _showAttackSheet(pixel, state);
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

  void _showAttackSheet(PixelModel pixel, MapState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AttackSheet(
        pixel: pixel,
        onAttack: () async {
          Navigator.pop(context);
          final battleId = await ref.read(mapProvider.notifier).startBattle(pixel.x, pixel.y);
          if (battleId != null && mounted) {
            context.go('/battle/$battleId');
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

    final pixelMap = <String, PixelModel>{};
    for (final p in state.pixels) {
      pixelMap['${p.x},${p.y}'] = p;
    }

    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Column(
          children: [
            _MapHeader(
              isLoading: state.isLoading,
              onBack: () => context.go('/resources'),
            ),
            _StatsBar(state: state, pixelMap: pixelMap),
            const _MapLegend(),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Container(
                  color: const Color(0xFF0A0A14),
                  child: InteractiveViewer(
                    transformationController: _transformCtrl,
                    minScale: 0.3,
                    maxScale: 6.0,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _PixelGrid(
                        pixelMap: pixelMap,
                        gridSize: gridSize,
                        pixelSize: pixelSize,
                        myUserId: state.myUserId,
                        onTap: (p) => _onPixelTap(p, state),
                        offsetX: state.offsetX,
                        offsetY: state.offsetY,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _MapControls(
              onMove: (dx, dy) {
                final newX = (state.offsetX + dx * gridSize).clamp(0, 150).toInt();
                final newY = (state.offsetY + dy * gridSize).clamp(0, 150).toInt();
                ref.read(mapProvider.notifier).loadChunk(newX, newY);
              },
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
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(CupertinoIcons.chevron_left,
                  color: AppColors.white, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Dünya Haritası',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
          if (isLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  color: AppColors.blue, strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}

// ── İstatistik Bar ───────────────────────────────────────
class _StatsBar extends StatelessWidget {
  final MapState state;
  final Map<String, PixelModel> pixelMap;

  const _StatsBar({required this.state, required this.pixelMap});

  @override
  Widget build(BuildContext context) {
    final myPixels =
        pixelMap.values.where((p) => p.ownerId == state.myUserId).length;
    final occupied =
        pixelMap.values.where((p) => p.ownerId != null).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(
        children: [
          _StatChip(
            icon: CupertinoIcons.square_grid_2x2,
            label: 'Piksellerim',
            value: '$myPixels',
            color: AppColors.green,
          ),
          const SizedBox(width: 10),
          _StatChip(
            icon: CupertinoIcons.flame,
            label: 'Aktif Alan',
            value: '$occupied',
            color: AppColors.red,
          ),
          const SizedBox(width: 10),
          _StatChip(
            icon: CupertinoIcons.location,
            label: 'Konum',
            value: '${state.offsetX},${state.offsetY}',
            color: AppColors.blue,
          ),
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

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Piksel Grid ──────────────────────────────────────────
class _PixelGrid extends StatelessWidget {
  final Map<String, PixelModel> pixelMap;
  final int gridSize;
  final double pixelSize;
  final String? myUserId;
  final void Function(PixelModel) onTap;
  final int offsetX;
  final int offsetY;

  const _PixelGrid({
    required this.pixelMap,
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
        painter: _PixelGridPainter(
          pixelMap: pixelMap,
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
            final x = offsetX + col;
            final y = offsetY + row;
            final pixel = pixelMap['$x,$y'] ??
                PixelModel(x: x, y: y, ownerId: null, ownerUsername: null, defensePower: 0);
            onTap(pixel);
          },
        ),
      ),
    );
  }
}

class _PixelGridPainter extends CustomPainter {
  final Map<String, PixelModel> pixelMap;
  final int gridSize;
  final double pixelSize;
  final String? myUserId;
  final int offsetX;
  final int offsetY;

  _PixelGridPainter({
    required this.pixelMap,
    required this.gridSize,
    required this.pixelSize,
    required this.myUserId,
    required this.offsetX,
    required this.offsetY,
  });

  // Savunma gücünü 0.0-1.0 arasına normalize et (log ölçeği)
  double _defenseIntensity(int defensePower) {
    if (defensePower <= 0) return 0.0;
    // 10 → ~0.2, 50 → ~0.5, 200 → ~0.8, 500+ → ~1.0
    return (math.log(defensePower + 1) / math.log(501)).clamp(0.0, 1.0);
  }

  Color _pixelColor(PixelModel? pixel, String? myUserId) {
    if (pixel == null || pixel.ownerId == null) return const Color(0xFF0D0D1A);

    final t = _defenseIntensity(pixel.defensePower);

    if (pixel.ownerId == myUserId) {
      // Benim: koyu yeşilden parlak yeşile
      return Color.lerp(const Color(0xFF0A3020), const Color(0xFF00FF88), t)!;
    } else {
      // Düşman: koyu kırmızıdan parlak kırmızıya
      return Color.lerp(const Color(0xFF2A0808), const Color(0xFFFF3B30), t)!;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = const Color(0xFF1C1C2E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        final x = offsetX + col;
        final y = offsetY + row;
        final pixel = pixelMap['$x,$y'];
        final rect = Rect.fromLTWH(
            col * pixelSize, row * pixelSize, pixelSize, pixelSize);

        canvas.drawRect(rect, Paint()..color = _pixelColor(pixel, myUserId));
        canvas.drawRect(rect, borderPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_PixelGridPainter old) =>
      old.pixelMap != pixelMap ||
      old.offsetX != offsetX ||
      old.offsetY != offsetY;
}

// ── Saldırı Bottom Sheet ─────────────────────────────────
class _AttackSheet extends StatelessWidget {
  final PixelModel pixel;
  final VoidCallback onAttack;

  const _AttackSheet({required this.pixel, required this.onAttack});

  @override
  Widget build(BuildContext context) {
    final isEmpty = pixel.ownerId == null;

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.surface3,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // İkon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isEmpty
                  ? AppColors.green.withOpacity(0.12)
                  : AppColors.red.withOpacity(0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              isEmpty ? CupertinoIcons.flag : CupertinoIcons.bolt_fill,
              color: isEmpty ? AppColors.green : AppColors.red,
              size: 30,
            ),
          ),

          const SizedBox(height: 16),

          Text(
            isEmpty ? 'Boş Arazi' : pixel.ownerUsername ?? 'Düşman Toprağı',
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Konum: (${pixel.x}, ${pixel.y})',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),

          if (!isEmpty) ...[
            const SizedBox(height: 16),
            _DefenseBar(defensePower: pixel.defensePower),
          ],

          const SizedBox(height: 28),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isEmpty ? AppColors.green : AppColors.red,
              ),
              onPressed: onAttack,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isEmpty ? CupertinoIcons.flag_fill : CupertinoIcons.bolt_fill,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isEmpty ? 'Toprağı Ele Geçir' : 'Saldırıya Geç',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Savunma Gücü Bar ─────────────────────────────────────
class _DefenseBar extends StatelessWidget {
  final int defensePower;
  const _DefenseBar({required this.defensePower});

  double get _fill => (math.log(defensePower + 1) / math.log(501)).clamp(0.0, 1.0);

  Color get _color {
    if (_fill < 0.33) return AppColors.green;
    if (_fill < 0.66) return AppColors.yellow;
    return AppColors.red;
  }

  String get _label {
    if (_fill < 0.33) return 'Zayıf savunma';
    if (_fill < 0.66) return 'Orta savunma';
    return 'Güçlü savunma';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_label,
                  style: TextStyle(color: _color, fontSize: 12, fontWeight: FontWeight.w600)),
              Text('Güç: $defensePower',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _fill,
              backgroundColor: AppColors.surface3,
              valueColor: AlwaysStoppedAnimation<Color>(_color),
              minHeight: 6,
            ),
          ),
        ],
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
          _LegendDot(color: const Color(0xFF00FF88), label: 'Senin'),
          const SizedBox(width: 16),
          _LegendDot(color: const Color(0xFFFF3B30), label: 'Düşman'),
          const SizedBox(width: 16),
          _LegendDot(color: const Color(0xFF0D0D1A), label: 'Boş'),
          const Spacer(),
          const Icon(CupertinoIcons.info_circle, color: AppColors.textTertiary, size: 13),
          const SizedBox(width: 4),
          const Text('Renk yoğunluğu = savunma',
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
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      ],
    );
  }
}

// ── Yön Kontrolleri ──────────────────────────────────────
class _MapControls extends StatelessWidget {
  final void Function(int dx, int dy) onMove;
  const _MapControls({required this.onMove});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.black,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _navBtn(CupertinoIcons.chevron_left, () => onMove(-1, 0)),
          const SizedBox(width: 8),
          Column(
            children: [
              _navBtn(CupertinoIcons.chevron_up, () => onMove(0, -1)),
              const SizedBox(height: 8),
              _navBtn(CupertinoIcons.chevron_down, () => onMove(0, 1)),
            ],
          ),
          const SizedBox(width: 8),
          _navBtn(CupertinoIcons.chevron_right, () => onMove(1, 0)),
        ],
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.white, size: 18),
      ),
    );
  }
}
