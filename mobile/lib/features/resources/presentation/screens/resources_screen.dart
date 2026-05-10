import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/resources_provider.dart';
import '../../data/models/resource_model.dart';

class ResourcesScreen extends ConsumerStatefulWidget {
  const ResourcesScreen({super.key});

  @override
  ConsumerState<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends ConsumerState<ResourcesScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(resourcesProvider);

    return Scaffold(
      backgroundColor: AppColors.black,
      body: IndexedStack(
        index: _selectedTab,
        children: [
          _HomeTab(state: state, ref: ref),
          const _PlaceholderTab(icon: CupertinoIcons.map, label: 'Harita'),
          const _PlaceholderTab(icon: CupertinoIcons.rosette, label: 'Liderboard'),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        selected: _selectedTab,
        onTap: (i) {
          if (i == 1) { context.go('/map'); return; }
          if (i == 2) { context.go('/leaderboard'); return; }
          setState(() => _selectedTab = i);
        },
      ),
    );
  }
}

// ── Ana Tab ──────────────────────────────────────────────
class _HomeTab extends StatelessWidget {
  final ResourcesState state;
  final WidgetRef ref;

  const _HomeTab({required this.state, required this.ref});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: state.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.blue))
          : state.resources == null
              ? _ErrorView(onRetry: () => ref.read(resourcesProvider.notifier).load())
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _Header()),
                    SliverToBoxAdapter(child: _ProfileCard(resources: state.resources!)),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                        child: Text(
                          'KAYNAKLAR',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _ResourceTile(
                            resource: state.resources!.gold,
                            icon: '💰',
                            label: 'Altın',
                            color: AppColors.yellow,
                            ref: ref,
                          ),
                          const SizedBox(height: 12),
                          _ResourceTile(
                            resource: state.resources!.wood,
                            icon: '🪵',
                            label: 'Odun',
                            color: const Color(0xFF8B4513),
                            ref: ref,
                          ),
                          const SizedBox(height: 12),
                          _ResourceTile(
                            resource: state.resources!.stone,
                            icon: '🪨',
                            label: 'Taş',
                            color: AppColors.textSecondary,
                            ref: ref,
                          ),
                          const SizedBox(height: 12),
                          _ResourceTile(
                            resource: state.resources!.iron,
                            icon: '⚙️',
                            label: 'Demir',
                            color: const Color(0xFF636366),
                            ref: ref,
                          ),
                          const SizedBox(height: 32),
                        ]),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        child: Text(
                          'BİNALAR',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _BuildingTile(
                            buildingType: 'sawmill',
                            label: 'Kereste Fabrikası',
                            icon: '🪚',
                            description: 'Otomatik Odun üretir',
                            costLabel: '50 Odun + 30 Taş',
                            resourceType: 'wood',
                            color: const Color(0xFF8B4513),
                            buildings: state.buildings,
                            resources: state.resources!,
                            ref: ref,
                          ),
                          const SizedBox(height: 12),
                          _BuildingTile(
                            buildingType: 'quarry',
                            label: 'Taş Ocağı',
                            icon: '⛏️',
                            description: 'Otomatik Taş üretir',
                            costLabel: '40 Odun + 50 Taş',
                            resourceType: 'stone',
                            color: AppColors.textSecondary,
                            buildings: state.buildings,
                            resources: state.resources!,
                            ref: ref,
                          ),
                          const SizedBox(height: 12),
                          _BuildingTile(
                            buildingType: 'forge',
                            label: 'Demir Dövücü',
                            icon: '🔨',
                            description: 'Otomatik Demir üretir',
                            costLabel: '60 Taş + 20 Demir',
                            resourceType: 'iron',
                            color: const Color(0xFF636366),
                            buildings: state.buildings,
                            resources: state.resources!,
                            ref: ref,
                          ),
                          const SizedBox(height: 12),
                          _BuildingTile(
                            buildingType: 'treasury',
                            label: 'Hazine',
                            icon: '🏦',
                            description: 'Otomatik Altın üretir',
                            costLabel: '50 Odun + 40 Altın',
                            resourceType: 'gold',
                            color: AppColors.yellow,
                            buildings: state.buildings,
                            resources: state.resources!,
                            ref: ref,
                          ),
                          const SizedBox(height: 32),
                        ]),
                      ),
                    ),
                  ],
                ),
    );
  }
}

// ── Header ───────────────────────────────────────────────
class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Pixel War',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(CupertinoIcons.bell, color: AppColors.white, size: 18),
          ),
        ],
      ),
    );
  }
}

// ── Profil Kartı ─────────────────────────────────────────
class _ProfileCard extends StatelessWidget {
  final AllResourcesModel resources;
  const _ProfileCard({required this.resources});

  @override
  Widget build(BuildContext context) {
    final totalResources = resources.gold.amount +
        resources.wood.amount +
        resources.stone.amount +
        resources.iron.amount;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A84FF), Color(0xFF0055D4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(CupertinoIcons.person_fill,
                    color: AppColors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Komutanım',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Savaşçı',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              // Seviye badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Sv. 1',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 20),

          // İstatistikler
          Row(
            children: [
              _StatItem(
                label: 'Toplam Kaynak',
                value: _fmt(totalResources),
                icon: CupertinoIcons.cube_box,
              ),
              _divider(),
              _StatItem(
                label: 'Piksel',
                value: '0',
                icon: CupertinoIcons.map,
              ),
              _divider(),
              _StatItem(
                label: 'Sıralama',
                value: '-',
                icon: CupertinoIcons.rosette,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1, height: 36,
        color: Colors.white24,
        margin: const EdgeInsets.symmetric(horizontal: 12),
      );

  String _fmt(double v) {
    if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(1)}B';
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatItem({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Kaynak Tile ──────────────────────────────────────────
class _ResourceTile extends StatefulWidget {
  final ResourceState resource;
  final String icon;
  final String label;
  final Color color;
  final WidgetRef ref;

  const _ResourceTile({
    required this.resource,
    required this.icon,
    required this.label,
    required this.color,
    required this.ref,
  });

  @override
  State<_ResourceTile> createState() => _ResourceTileState();
}

class _ResourceTileState extends State<_ResourceTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  OverlayEntry? _floatEntry;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 80));
    _scale = Tween(begin: 1.0, end: 0.97)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTap() {
    _ctrl.forward().then((_) => _ctrl.reverse());
    widget.ref
        .read(resourcesProvider.notifier)
        .tap(widget.resource.resourceType);
    _showFloat();
  }

  void _onLongPress() {
    _showUpgradeSheet(context);
  }

  void _showUpgradeSheet(BuildContext context) {
    final resource = widget.resource;
    final nextLevel = resource.tapPowerLevel + 1;
    final cost = 100 * (3.0.toInt() * resource.tapPowerLevel.toInt());

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(widget.icon, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.label} - Tıklama Yükselt',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Mevcut güç: ${resource.tapPower}/tık',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.black,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Seviye $nextLevel',
                          style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w600)),
                      Text('+${(2.0 * resource.tapPower).toInt()}/tık',
                          style: TextStyle(color: widget.color, fontSize: 13)),
                    ],
                  ),
                  Text(
                    '💰 ${_fmtCost(cost.toDouble())} Altın',
                    style: const TextStyle(color: AppColors.yellow, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.color,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    await widget.ref
                        .read(resourcesProvider.notifier)
                        .upgradeTap(resource.resourceType);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(_friendlyError(e)), backgroundColor: Colors.red[700]),
                      );
                    }
                  }
                },
                child: const Text('Yükselt', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _fmtCost(double v) {
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  String _friendlyError(Object e) {
    if (e is DioException) {
      final detail = e.response?.data?['detail'];
      if (detail != null) return detail.toString();
    }
    return 'Yükseltme başarısız';
  }

  void _showFloat() {
    final overlay = Overlay.of(context);
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos = box.localToGlobal(Offset(box.size.width / 2, 0));

    _floatEntry = OverlayEntry(builder: (_) => _FloatText(
      position: pos,
      text: '+${widget.resource.tapPower}',
      color: widget.color,
      onDone: () => _floatEntry?.remove(),
    ));
    overlay.insert(_floatEntry!);
  }

  String _fmt(double v) {
    if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(1)}B';
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: _onTap,
        onLongPress: _onLongPress,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              // İkon kutusu
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(widget.icon, style: const TextStyle(fontSize: 26)),
                ),
              ),
              const SizedBox(width: 16),

              // Bilgiler
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _fmt(widget.resource.amount),
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              // Sağ taraf
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '+${widget.resource.tapPower}/tık',
                      style: TextStyle(
                        color: widget.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (widget.resource.autoRate > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '+${widget.resource.autoRate.toStringAsFixed(1)}/s',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ],
              ),

              const SizedBox(width: 12),
              const Icon(CupertinoIcons.chevron_right,
                  color: AppColors.textTertiary, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Uçan +N animasyonu ───────────────────────────────────
class _FloatText extends StatefulWidget {
  final Offset position;
  final String text;
  final Color color;
  final VoidCallback onDone;

  const _FloatText({
    required this.position,
    required this.text,
    required this.color,
    required this.onDone,
  });

  @override
  State<_FloatText> createState() => _FloatTextState();
}

class _FloatTextState extends State<_FloatText>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _y;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _y = Tween(begin: 0.0, end: -50.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacity = Tween(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
    _ctrl.forward().then((_) => widget.onDone());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Positioned(
        left: widget.position.dx - 20,
        top: widget.position.dy + _y.value,
        child: Opacity(
          opacity: _opacity.value,
          child: Text(
            widget.text,
            style: TextStyle(
              color: widget.color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Alt Navigasyon ───────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int selected;
  final void Function(int) onTap;

  const _BottomNav({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.surface3, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: CupertinoIcons.home, label: 'Ana Sayfa',
                  selected: selected == 0, onTap: () => onTap(0)),
              _NavItem(icon: CupertinoIcons.map, label: 'Harita',
                  selected: selected == 1, onTap: () => onTap(1)),
              _NavItem(icon: CupertinoIcons.rosette, label: 'Sıralama',
                  selected: selected == 2, onTap: () => onTap(2)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: selected ? AppColors.blue : AppColors.textSecondary,
                size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.blue : AppColors.textSecondary,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bina Tile ────────────────────────────────────────────
class _BuildingTile extends StatelessWidget {
  final String buildingType;
  final String label;
  final String icon;
  final String description;
  final String costLabel;
  final String resourceType;
  final Color color;
  final List<BuildingModel> buildings;
  final AllResourcesModel resources;
  final WidgetRef ref;

  const _BuildingTile({
    required this.buildingType,
    required this.label,
    required this.icon,
    required this.description,
    required this.costLabel,
    required this.resourceType,
    required this.color,
    required this.buildings,
    required this.resources,
    required this.ref,
  });

  BuildingModel? get _building =>
      buildings.where((b) => b.buildingType == buildingType).firstOrNull;

  String _fmt(double v) {
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  String _upgradeCostLabel(int currentLevel) {
    final multiplier = (1 << currentLevel); // 2^level
    final parts = costLabel.split(' + ');
    final scaled = parts.map((p) {
      final match = RegExp(r'^(\d+)\s+(.+)$').firstMatch(p.trim());
      if (match == null) return p;
      final amount = int.parse(match.group(1)!) * multiplier;
      return '${_fmt(amount.toDouble())} ${match.group(2)}';
    });
    return scaled.join(' + ');
  }

  void _onBuild(BuildContext context) async {
    try {
      await ref.read(resourcesProvider.notifier).buildOrUpgrade(buildingType);
    } catch (e) {
      if (context.mounted) {
        String msg = 'İşlem başarısız';
        if (e is DioException) {
          final detail = e.response?.data?['detail'];
          if (detail != null) msg = detail.toString();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red[700]),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final building = _building;
    final level = building?.level ?? 0;
    final isBuilt = level > 0;
    final autoRate = building?.productionRate ?? 0;
    final displayCost = isBuilt ? _upgradeCostLabel(level) : costLabel;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: isBuilt
            ? Border.all(color: color.withOpacity(0.3), width: 1)
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(isBuilt ? 0.2 : 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(icon, style: const TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isBuilt) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Sv.$level',
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isBuilt
                      ? '+${autoRate.toStringAsFixed(1)}/s $description'
                      : description,
                  style: TextStyle(
                    color: isBuilt ? color : AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isBuilt ? 'Yükselt: $displayCost' : 'İnşa: $displayCost',
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _onBuild(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Text(
                isBuilt ? 'Yükselt' : 'İnşa Et',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Yardımcılar ──────────────────────────────────────────
class _PlaceholderTab extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PlaceholderTab({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 48),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.wifi_slash,
                color: AppColors.textSecondary, size: 48),
            const SizedBox(height: 16),
            const Text('Bağlantı hatası',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Tekrar Dene')),
          ],
        ),
      );
}
