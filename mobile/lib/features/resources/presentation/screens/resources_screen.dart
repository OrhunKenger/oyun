import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/resources_provider.dart';
import '../../data/models/resource_model.dart';

class ResourcesScreen extends ConsumerWidget {
  const ResourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(resourcesProvider);

    return Scaffold(
      backgroundColor: AppTheme.primary,
      appBar: AppBar(
        backgroundColor: AppTheme.secondary,
        title: const Text('PIXEL WAR', style: TextStyle(color: AppTheme.accent, letterSpacing: 4)),
        actions: [
          IconButton(
            icon: const Icon(Icons.map, color: Colors.white),
            onPressed: () => context.go('/map'),
          ),
          IconButton(
            icon: const Icon(Icons.leaderboard, color: Colors.white),
            onPressed: () => context.go('/leaderboard'),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : state.resources == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(state.error ?? 'Hata', style: const TextStyle(color: AppTheme.accent)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.read(resourcesProvider.notifier).load(),
                        child: const Text('Tekrar Dene'),
                      ),
                    ],
                  ),
                )
              : _buildBody(context, ref, state.resources!),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, AllResourcesModel resources) {
    final items = [
      _ResourceItem(resource: resources.gold, icon: '💰', color: AppTheme.gold, label: 'ALTIN'),
      _ResourceItem(resource: resources.wood, icon: '🪵', color: AppTheme.wood, label: 'ODUN'),
      _ResourceItem(resource: resources.stone, icon: '🪨', color: AppTheme.stone, label: 'TAŞ'),
      _ResourceItem(resource: resources.iron, icon: '⚙️', color: const Color(0xFFB0C4DE), label: 'DEMİR'),
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const _PixelDivider(),
          const SizedBox(height: 8),
          const Text(
            'KAYNAKLARIN',
            style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 4),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: items.map((item) => _ResourceCard(item: item, ref: ref)).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResourceItem {
  final ResourceState resource;
  final String icon;
  final Color color;
  final String label;

  _ResourceItem({
    required this.resource,
    required this.icon,
    required this.color,
    required this.label,
  });
}

class _ResourceCard extends StatefulWidget {
  final _ResourceItem item;
  final WidgetRef ref;

  const _ResourceCard({required this.item, required this.ref});

  @override
  State<_ResourceCard> createState() => _ResourceCardState();
}

class _ResourceCardState extends State<_ResourceCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 80));
    _scale = Tween(begin: 1.0, end: 0.92).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTap() {
    _ctrl.forward().then((_) => _ctrl.reverse());
    widget.ref.read(resourcesProvider.notifier).tap(widget.item.resource.resourceType);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final amount = item.resource.amount;

    return GestureDetector(
      onTap: _onTap,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.secondary,
            border: Border.all(color: item.color, width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(item.icon, style: const TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text(
                item.label,
                style: TextStyle(
                  color: item.color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _format(amount),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '+${item.resource.tapPower}/tık',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              if (item.resource.autoRate > 0)
                Text(
                  '+${item.resource.autoRate.toStringAsFixed(1)}/s',
                  style: TextStyle(color: item.color.withOpacity(0.7), fontSize: 10),
                ),
              const SizedBox(height: 8),
              _UpgradeButton(
                item: item,
                onTap: () => widget.ref
                    .read(resourcesProvider.notifier)
                    .upgradeTap(item.resource.resourceType),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _format(double v) {
    if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(1)}B';
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

class _UpgradeButton extends StatelessWidget {
  final _ResourceItem item;
  final VoidCallback onTap;

  const _UpgradeButton({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cost = 100 * (3.0.pow(item.resource.tapPowerLevel));
    final canAfford = item.resource.resourceType == 'gold'
        ? item.resource.amount >= cost
        : true; // altın kontrolü provider'da yapılıyor

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: canAfford ? item.color.withOpacity(0.2) : Colors.white10,
          border: Border.all(color: canAfford ? item.color : Colors.white24),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'TIK GÜÇ LV.${item.resource.tapPowerLevel}',
          style: TextStyle(
            color: canAfford ? item.color : Colors.white38,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _PixelDivider extends StatelessWidget {
  const _PixelDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        20,
        (i) => Expanded(
          child: Container(
            height: 2,
            color: i % 2 == 0 ? AppTheme.accent : Colors.transparent,
            margin: const EdgeInsets.symmetric(horizontal: 1),
          ),
        ),
      ),
    );
  }
}

extension on double {
  double pow(int exp) {
    double result = 1;
    for (int i = 0; i < exp; i++) result *= this;
    return result;
  }
}
