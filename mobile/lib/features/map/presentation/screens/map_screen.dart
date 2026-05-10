import 'package:flutter/material.dart';
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

  PixelModel? _selected;
  final TransformationController _transformCtrl = TransformationController();

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  void _onPixelTap(PixelModel pixel, MapState state) {
    if (pixel.ownerId == state.myUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu piksel senin!'), backgroundColor: Color(0xFF00FF88)),
      );
      return;
    }
    setState(() => _selected = pixel);
    _showAttackDialog(pixel, state);
  }

  void _showAttackDialog(PixelModel pixel, MapState state) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.secondary,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppTheme.accent, width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
        title: Text(
          pixel.ownerId == null ? 'BOŞ ARAZI' : '${pixel.ownerUsername ?? "Düşman"} SALDIRI',
          style: const TextStyle(color: AppTheme.accent, letterSpacing: 2),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Konum: (${pixel.x}, ${pixel.y})', style: const TextStyle(color: Colors.white54)),
            Text('Savunma: ${pixel.defensePower}', style: const TextStyle(color: Colors.white54)),
            const SizedBox(height: 8),
            const Text(
              'Tıklama savaşı başlatmak istiyor musun?',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İPTAL', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
            onPressed: () async {
              Navigator.pop(context);
              final battleId = await ref.read(mapProvider.notifier).startBattle(pixel.x, pixel.y);
              if (battleId != null && mounted) {
                context.go('/battle/$battleId');
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Savaş başlatılamadı'), backgroundColor: AppTheme.accent),
                );
              }
            },
            child: const Text('SALDIRI BAŞLAT', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
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
      backgroundColor: AppTheme.primary,
      appBar: AppBar(
        backgroundColor: AppTheme.secondary,
        title: const Text('DÜNYA HARİTASI', style: TextStyle(color: AppTheme.accent, letterSpacing: 3, fontSize: 14)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/resources'),
        ),
        actions: [
          if (state.isLoading)
            const Center(child: Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 2)),
            )),
        ],
      ),
      body: Column(
        children: [
          _Legend(myUserId: state.myUserId),
          Expanded(
            child: InteractiveViewer(
              transformationController: _transformCtrl,
              minScale: 0.3,
              maxScale: 5.0,
              child: Padding(
                padding: const EdgeInsets.all(8),
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
          _MapControls(
            onMove: (dx, dy) {
              final newX = (state.offsetX + dx * gridSize).clamp(0, 150).toInt();
              final newY = (state.offsetY + dy * gridSize).clamp(0, 150).toInt();
              ref.read(mapProvider.notifier).loadChunk(newX, newY);
            },
          ),
        ],
      ),
    );
  }
}

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

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = AppTheme.pixelBorder.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        final x = offsetX + col;
        final y = offsetY + row;
        final pixel = pixelMap['$x,$y'];

        final rect = Rect.fromLTWH(col * pixelSize, row * pixelSize, pixelSize, pixelSize);

        final fillPaint = Paint()
          ..color = pixel?.toColor(myUserId) ?? const Color(0xFF0D0D1A);
        canvas.drawRect(rect, fillPaint);
        canvas.drawRect(rect, borderPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_PixelGridPainter old) =>
      old.pixelMap != pixelMap || old.offsetX != offsetX || old.offsetY != offsetY;
}

class _Legend extends StatelessWidget {
  final String? myUserId;
  const _Legend({this.myUserId});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.secondary,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          _dot(const Color(0xFF00FF88)),
          const SizedBox(width: 4),
          const Text('Senin', style: TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(width: 16),
          _dot(const Color(0xFFE94560)),
          const SizedBox(width: 4),
          const Text('Düşman', style: TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(width: 16),
          _dot(const Color(0xFF0D0D1A)),
          const SizedBox(width: 4),
          const Text('Boş', style: TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _dot(Color c) => Container(
        width: 12, height: 12,
        decoration: BoxDecoration(color: c, border: Border.all(color: Colors.white24)),
      );
}

class _MapControls extends StatelessWidget {
  final void Function(int dx, int dy) onMove;
  const _MapControls({required this.onMove});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.secondary,
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _navBtn(Icons.arrow_back, () => onMove(-1, 0)),
          Column(
            children: [
              _navBtn(Icons.arrow_upward, () => onMove(0, -1)),
              const SizedBox(height: 4),
              _navBtn(Icons.arrow_downward, () => onMove(0, 1)),
            ],
          ),
          _navBtn(Icons.arrow_forward, () => onMove(1, 0)),
        ],
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback onTap) => IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white70, size: 20),
        style: IconButton.styleFrom(backgroundColor: AppTheme.pixelBorder),
      );
}
