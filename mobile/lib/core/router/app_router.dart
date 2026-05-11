import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/profile_screen.dart';
import '../../features/resources/presentation/screens/resources_screen.dart';
import '../../features/map/presentation/screens/map_screen.dart';
import '../../features/battle/presentation/screens/battle_screen.dart';
import '../../features/leaderboard/presentation/screens/leaderboard_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (ctx, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (ctx, state) => const RegisterScreen()),
      GoRoute(path: '/resources', builder: (ctx, state) => const ResourcesScreen()),
      GoRoute(path: '/profile', builder: (ctx, state) => const ProfileScreen()),
      GoRoute(path: '/map', builder: (ctx, state) => const MapScreen()),
      GoRoute(
        path: '/battle/:battleId',
        builder: (ctx, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return BattleScreen(
            battleId: state.pathParameters['battleId']!,
            defenderUsername: extra?['defenderUsername'] as String?,
            defenderPower: extra?['defenderPower'] as double?,
          );
        },
      ),
      GoRoute(path: '/leaderboard', builder: (ctx, state) => const LeaderboardScreen()),
    ],
  );
});
