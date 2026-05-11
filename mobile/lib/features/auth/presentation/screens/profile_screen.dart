import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/profile_provider.dart';
import '../providers/auth_provider.dart';
import '../../../resources/presentation/providers/resources_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileProvider);
    final resourcesState = ref.watch(resourcesProvider);

    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: profileState.isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.blue))
            : profileState.profile == null
                ? _ErrorView(onRetry: () => ref.read(profileProvider.notifier).load())
                : CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _AppBar(context: context)),
                      SliverToBoxAdapter(
                        child: _AvatarCard(
                          username: profileState.profile!.username,
                          level: profileState.profile!.level,
                          prestige: profileState.profile!.prestige,
                          email: profileState.profile!.email,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _StatsGrid(profile: profileState.profile!),
                      ),
                      if (resourcesState.resources != null)
                        SliverToBoxAdapter(
                          child: _ResourcesCard(resources: resourcesState.resources!),
                        ),
                      SliverToBoxAdapter(
                        child: _Actions(
                          onLogout: () async {
                            await ref.read(authProvider.notifier).logout();
                            if (context.mounted) context.go('/login');
                          },
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 32)),
                    ],
                  ),
      ),
    );
  }
}

// ── App Bar ──────────────────────────────────────────────
class _AppBar extends StatelessWidget {
  final BuildContext context;
  const _AppBar({required this.context});

  @override
  Widget build(BuildContext ctx) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 20, 0),
      child: Row(
        children: [
          CupertinoButton(
            padding: const EdgeInsets.all(8),
            onPressed: () => context.pop(),
            child: const Icon(CupertinoIcons.chevron_left, color: AppColors.blue, size: 22),
          ),
          const Expanded(
            child: Text(
              'Profil',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Avatar Kartı ─────────────────────────────────────────
class _AvatarCard extends StatelessWidget {
  final String username;
  final int level;
  final int prestige;
  final String email;

  const _AvatarCard({
    required this.username,
    required this.level,
    required this.prestige,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    final initials = username.length >= 2
        ? username.substring(0, 2).toUpperCase()
        : username.toUpperCase();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A84FF), Color(0xFF0055D4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            username,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Badge(label: 'Seviye $level', color: Colors.white.withOpacity(0.2)),
              const SizedBox(width: 10),
              if (prestige > 0)
                _Badge(label: '★ Prestij $prestige', color: AppColors.yellow.withOpacity(0.3)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── İstatistikler Grid ───────────────────────────────────
class _StatsGrid extends StatelessWidget {
  final profile;
  const _StatsGrid({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _StatRow(
            icon: CupertinoIcons.map,
            label: 'Sahip Piksel',
            value: '${profile.pixelCount}',
            color: AppColors.blue,
          ),
          _divider(),
          _StatRow(
            icon: CupertinoIcons.star_fill,
            label: 'Toplam Puan',
            value: _fmt(profile.totalScore.toDouble()),
            color: AppColors.yellow,
          ),
          _divider(),
          _StatRow(
            icon: CupertinoIcons.hand_point_right_fill,
            label: 'Tıklama Gücü',
            value: '${profile.tapPower}',
            color: AppColors.green,
          ),
        ],
      ),
    );
  }

  Widget _divider() => const Divider(
        height: 1,
        color: Color(0xFF2C2C2E),
        indent: 56,
      );

  String _fmt(double v) {
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Kaynaklar Özet ───────────────────────────────────────
class _ResourcesCard extends StatelessWidget {
  final resources;
  const _ResourcesCard({required this.resources});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'KAYNAKLAR',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Row(
            children: [
              _ResItem(icon: '💰', label: 'Altın', amount: resources.gold.amount),
              _ResItem(icon: '🪵', label: 'Odun', amount: resources.wood.amount),
              _ResItem(icon: '🪨', label: 'Taş', amount: resources.stone.amount),
              _ResItem(icon: '⚙️', label: 'Demir', amount: resources.iron.amount),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResItem extends StatelessWidget {
  final String icon;
  final String label;
  final double amount;
  const _ResItem({required this.icon, required this.label, required this.amount});

  String _fmt(double v) {
    if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(1)}B';
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 4),
          Text(
            _fmt(amount),
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

// ── Çıkış Butonu ─────────────────────────────────────────
class _Actions extends StatelessWidget {
  final VoidCallback onLogout;
  const _Actions({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: GestureDetector(
        onTap: onLogout,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.red.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.red.withOpacity(0.3)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.square_arrow_left, color: AppColors.red, size: 18),
              SizedBox(width: 8),
              Text(
                'Çıkış Yap',
                style: TextStyle(
                  color: AppColors.red,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Hata ─────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.wifi_slash, color: AppColors.textSecondary, size: 48),
            const SizedBox(height: 16),
            const Text('Yüklenemedi', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Tekrar Dene')),
          ],
        ),
      );
}
