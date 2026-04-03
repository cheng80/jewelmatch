import 'package:go_router/go_router.dart';

import 'app_config.dart';
import 'game/jewel_game_mode.dart';
import 'views/game_view.dart';
import 'views/setting_view.dart';
import 'views/title_view.dart';

/// 앱 전체 라우팅 설정.
final GoRouter appRouter = GoRouter(
  initialLocation: RoutePaths.title,
  routes: [
    GoRoute(
      path: RoutePaths.title,
      builder: (context, state) => const TitleView(),
    ),
    GoRoute(
      path: RoutePaths.game,
      builder: (context, state) {
        final mode = JewelGameMode.fromQuery(
          state.uri.queryParameters['mode'],
        );
        return GameView(gameMode: mode);
      },
    ),
    GoRoute(
      path: RoutePaths.setting,
      builder: (context, state) => const SettingView(),
    ),
  ],
);
