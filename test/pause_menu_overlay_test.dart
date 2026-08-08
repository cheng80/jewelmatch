import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:stonematch/game/jewel_game_mode.dart';
import 'package:stonematch/game/match_board_game.dart';
import 'package:stonematch/services/ranking_service.dart';
import 'package:stonematch/utils/storage_helper.dart';
import 'package:stonematch/views/overlays/pause_menu_overlay.dart';
import 'package:stonematch/vm/ranking_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageHelper.init();
    await StorageHelper.erase();
  });

  testWidgets('pause menu shows action buttons without audio controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: EasyLocalization(
          supportedLocales: const [Locale('ko')],
          path: 'assets/translations',
          assetLoader: const _TestAssetLoader(),
          fallbackLocale: const Locale('ko'),
          startLocale: const Locale('ko'),
          child: Builder(
            builder: (context) => MaterialApp(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              home: PauseMenuOverlay(
                game: MatchBoardGame(gameMode: JewelGameMode.simple),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Slider), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(find.text('배경음악'), findsNothing);
    expect(find.text('효과음'), findsNothing);
    expect(find.text('계속하기'), findsOneWidget);
    expect(find.text('다시하기'), findsOneWidget);
    expect(find.text('나가기'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(find.byIcon(Icons.restart_alt_rounded), findsOneWidget);
    expect(find.byIcon(Icons.logout_rounded), findsOneWidget);
    expect(find.byIcon(Icons.bar_chart_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pause exit waits for reached level ranking submission', (
    tester,
  ) async {
    final game = MatchBoardGame(gameMode: JewelGameMode.progression)
      ..progressionLevel = 4;
    final submitCompleter = Completer<void>();
    late _DelayedRankingNotifier notifier;
    final router = GoRouter(
      initialLocation: '/game',
      overridePlatformDefaultLocation: true,
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('title')),
        GoRoute(
          path: '/game',
          builder: (_, _) => PauseMenuOverlay(game: game),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rankingProvider.overrideWith(
            () => notifier = _DelayedRankingNotifier(submitCompleter),
          ),
        ],
        child: EasyLocalization(
          supportedLocales: const [Locale('ko')],
          path: 'assets/translations',
          assetLoader: const _TestAssetLoader(),
          fallbackLocale: const Locale('ko'),
          startLocale: const Locale('ko'),
          child: Builder(
            builder: (context) => MaterialApp.router(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              routerConfig: router,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final exitButton = find.ancestor(
      of: find.text('나가기'),
      matching: find.byType(InkWell),
    );
    tester.widget<InkWell>(exitButton).onTap!();
    await tester.pump();
    tester.widget<InkWell>(exitButton).onTap!();
    await tester.pump();

    expect(notifier.calls, 1);
    expect(notifier.mode, RankingMode.level);
    expect(notifier.score, 3);
    expect(router.routeInformationProvider.value.uri.path, '/game');

    submitCompleter.complete();
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(find.text('title'), findsOneWidget);
  });
}

class _TestAssetLoader extends AssetLoader {
  const _TestAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => {
    'paused': '일시정지',
    'continueGame': '계속하기',
    'retry': '다시하기',
    'exit': '나가기',
    'settings': '설정',
    'statsButton': '통계',
    'rankLevelSuccess': '레벨 랭킹',
    'rankSuccess': '랭킹',
    'rankNotInTop': '순위 밖',
    'rankNotFound': '없음',
    'rankLoadFailed': '조회 실패',
    'rankSaveFailed': '저장 실패',
    'rankSubmitFailed': '제출 실패',
  };
}

class _DelayedRankingNotifier extends RankingNotifier {
  _DelayedRankingNotifier(this.completer);

  final Completer<void> completer;
  int calls = 0;
  RankingMode? mode;
  int? score;

  @override
  Future<void> submit({
    required RankingMode mode,
    required int score,
    required String trRankSuccess,
    required String trRankNotInTop,
    required String trRankNotFound,
    required String trRankLoadFailed,
    required String trRankSaveFailed,
    required String trRankSubmitFailed,
  }) async {
    calls++;
    this.mode = mode;
    this.score = score;
    state = state.copyWith(isSubmitting: true);
    await completer.future;
    state = const RankingSubmitState(submitted: true);
  }
}
