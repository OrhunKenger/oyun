import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';

final leaderboardProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final res = await ApiClient().dio.get('/leaderboard/');
  return res.data;
});

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(leaderboardProvider);

    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Column(
          children: [
            _Header(onRefresh: () => ref.invalidate(leaderboardProvider)),
            Expanded(
              child: async.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.blue),
                ),
                error: (e, _) => _ErrorView(
                  onRetry: () => ref.invalidate(leaderboardProvider),
                ),
                data: (data) {
                  final entries = data['entries'] as List? ?? [];
                  final myRank = data['my_rank'] as int?;
                  final total = data['total_players'] as int?;
                  return _LeaderboardBody(
                    entries: entries,
                    myRank: myRank,
                    total: total,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────
class _Header extends StatelessWidget {
  final VoidCallback onRefresh;
  const _Header({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.go('/resources'),
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
              'Sıralama',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
          GestureDetector(
            onTap: onRefresh,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(CupertinoIcons.refresh,
                  color: AppColors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Body ─────────────────────────────────────────────────
class _LeaderboardBody extends StatelessWidget {
  final List entries;
  final int? myRank;
  final int? total;

  const _LeaderboardBody({
    required this.entries,
    required this.myRank,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final top3 = entries.take(3).toList();
    final rest = entries.skip(3).toList();

    return CustomScrollView(
      slivers: [
        // Podium
        if (top3.isNotEmpty)
          SliverToBoxAdapter(child: _Podium(top3: top3)),

        // Kendi sıran
        if (myRank != null)
          SliverToBoxAdapter(
            child: _MyRankCard(myRank: myRank!, total: total ?? 0),
          ),

        // Başlık
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Text(
              'TÜM OYUNCULAR',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),

        // Liste
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final e = entries[i] as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _LeaderboardTile(entry: e),
                );
              },
              childCount: entries.length,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Podium ───────────────────────────────────────────────
class _Podium extends StatelessWidget {
  final List top3;
  const _Podium({required this.top3});

  @override
  Widget build(BuildContext context) {
    final first = top3.isNotEmpty ? top3[0] as Map<String, dynamic> : null;
    final second = top3.length > 1 ? top3[1] as Map<String, dynamic> : null;
    final third = top3.length > 2 ? top3[2] as Map<String, dynamic> : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (second != null)
            Expanded(child: _PodiumItem(entry: second, rank: 2, height: 100)),
          const SizedBox(width: 8),
          if (first != null)
            Expanded(child: _PodiumItem(entry: first, rank: 1, height: 130)),
          const SizedBox(width: 8),
          if (third != null)
            Expanded(child: _PodiumItem(entry: third, rank: 3, height: 80)),
        ],
      ),
    );
  }
}

class _PodiumItem extends StatelessWidget {
  final Map<String, dynamic> entry;
  final int rank;
  final double height;

  const _PodiumItem({
    required this.entry,
    required this.rank,
    required this.height,
  });

  Color get _color {
    if (rank == 1) return AppColors.yellow;
    if (rank == 2) return const Color(0xFFC0C0C0);
    return const Color(0xFFCD7F32);
  }

  String get _medal {
    if (rank == 1) return '👑';
    if (rank == 2) return '🥈';
    return '🥉';
  }

  @override
  Widget build(BuildContext context) {
    final username = entry['username'] as String? ?? '?';
    final pixels = entry['pixel_count'] as int? ?? 0;

    return Column(
      children: [
        Text(_medal, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 6),
        Text(
          username.length > 8 ? '${username.substring(0, 8)}..' : username,
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          '$pixels px',
          style: TextStyle(color: _color, fontSize: 11, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Container(
          height: height,
          decoration: BoxDecoration(
            color: _color.withOpacity(0.12),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border.all(color: _color.withOpacity(0.3), width: 1),
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: TextStyle(
                color: _color,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Kendi Sıram Kartı ────────────────────────────────────
class _MyRankCard extends StatelessWidget {
  final int myRank;
  final int total;
  const _MyRankCard({required this.myRank, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.blue.withOpacity(0.2),
            AppColors.blue.withOpacity(0.05),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.blue.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.blue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(CupertinoIcons.person_fill,
                color: AppColors.blue, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Senin Sıran',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  '#$myRank / $total oyuncu',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.blue,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '#$myRank',
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sıralama Satırı ──────────────────────────────────────
class _LeaderboardTile extends StatelessWidget {
  final Map<String, dynamic> entry;
  const _LeaderboardTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final rank = entry['rank'] as int? ?? 0;
    final username = entry['username'] as String? ?? '?';
    final pixels = entry['pixel_count'] as int? ?? 0;
    final prestige = entry['prestige'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '#$rank',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.surface3,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                username[0].toUpperCase(),
                style: const TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (prestige > 0)
                  Row(
                    children: [
                      const Icon(CupertinoIcons.star_fill,
                          color: AppColors.yellow, size: 10),
                      const SizedBox(width: 3),
                      Text(
                        'Prestige $prestige',
                        style: const TextStyle(
                            color: AppColors.yellow, fontSize: 11),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$pixels',
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Text(
                'piksel',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Hata ─────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(CupertinoIcons.wifi_slash,
              color: AppColors.textSecondary, size: 48),
          const SizedBox(height: 16),
          const Text('Bağlantı hatası',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Tekrar Dene'),
          ),
        ],
      ),
    );
  }
}
