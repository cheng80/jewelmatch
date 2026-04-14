import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_config.dart';
import 'game/jewel_game_mode.dart';
import 'views/game_view.dart';
import 'views/setting_view.dart';
import 'views/sfx_test_view.dart';
import 'views/title_view.dart';

/// 앱 전체 라우팅 설정.
final GoRouter appRouter = GoRouter(
  initialLocation: RoutePaths.title,
  routes: [
    GoRoute(
      path: RoutePaths.title,
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const TitleView(),
          transitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (context, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        );
      },
    ),
    GoRoute(
      path: RoutePaths.game,
      pageBuilder: (context, state) {
        final mode = JewelGameMode.fromQuery(
          state.uri.queryParameters['mode'],
        );
        return CustomTransitionPage(
          key: state.pageKey,
          child: GameView(gameMode: mode),
          transitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (context, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        );
      },
    ),
    GoRoute(
      path: RoutePaths.setting,
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const SettingView(),
          transitionDuration: const Duration(milliseconds: 350),
          transitionsBuilder: (context, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        );
      },
    ),
    GoRoute(
      path: RoutePaths.sfxTest,
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const SfxTestView(),
          transitionDuration: const Duration(milliseconds: 350),
          transitionsBuilder: (context, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        );
      },
    ),
  ],
);
