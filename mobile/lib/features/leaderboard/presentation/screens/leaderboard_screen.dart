import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
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
      backgroundColor: AppTheme.primary,
      appBar: AppBar(
        backgroundColor: AppTheme.secondary,
        title: const Text('LİDERLİK TABLOSU', style: TextStyle(color: AppTheme.accent, letterSpacing: 3, fontSize: 13)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/resources'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => ref.invalidate(leaderboardProvider),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
        error: (e, _) => Center(child: Text('Hata: $e', style: const TextStyle(color: AppTheme.accent))),
        data: (data) {
          final entries = data['entries'] as List? ?? [];
          final myRank = data['my_rank'];
          final total = data['total_players'];

          return Column(
            children: [
              _MyRankBanner(myRank: myRank, total: total),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: entries.length,
                  itemBuilder: (ctx, i) {
                    final e = entries[i] as Map<String, dynamic>;
                    return _LeaderboardTile(entry: e, index: i);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MyRankBanner extends StatelessWidget {
  final int? myRank;
  final int? total;

  const _MyRankBanner({this.myRank, this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.secondary,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('SENİN SIRAN: ', style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 2)),
          Text(
            myRank != null ? '#$myRank' : '-',
            style: const TextStyle(color: AppTheme.gold, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          if (total != null)
            Text(' / $total', style: const TextStyle(color: Colors.white38, fontSize: 14)),
        ],
      ),
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  final Map<String, dynamic> entry;
  final int index;

  const _LeaderboardTile({required this.entry, required this.index});

  @override
  Widget build(BuildContext context) {
    final rank = entry['rank'] as int? ?? index + 1;
    final username = entry['username'] as String? ?? '?';
    final pixels = entry['pixel_count'] as int? ?? 0;
    final prestige = entry['prestige'] as int? ?? 0;

    Color rankColor = Colors.white54;
    String rankIcon = '$rank';
    if (rank == 1) { rankColor = AppTheme.gold; rankIcon = '👑'; }
    else if (rank == 2) { rankColor = const Color(0xFFC0C0C0); rankIcon = '🥈'; }
    else if (rank == 3) { rankColor = const Color(0xFFCD7F32); rankIcon = '🥉'; }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.secondary,
        border: Border.all(
          color: rank <= 3 ? rankColor.withOpacity(0.5) : AppTheme.pixelBorder,
          width: rank <= 3 ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(rankIcon, style: TextStyle(color: rankColor, fontSize: rank <= 3 ? 20 : 14, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                if (prestige > 0)
                  Text('✨ Prestige $prestige', style: const TextStyle(color: AppTheme.accent, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$pixels piksel', style: TextStyle(color: rankColor, fontWeight: FontWeight.bold)),
              const Text('toprak', style: TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}
