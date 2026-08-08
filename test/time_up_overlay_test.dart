import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/game/jewel_game_mode.dart';
import 'package:stonematch/game/match_board_game.dart';
import 'package:stonematch/views/overlays/time_up_overlay.dart';
import 'package:stonematch/vm/ranking_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('empty progression result stays out of ranking', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final game = MatchBoardGame(gameMode: JewelGameMode.progression);

    await tester.pumpWidget(
      ProviderScope(
        child: EasyLocalization(
          supportedLocales: const [Locale('ko')],
          path: 'assets/translations',
          fallbackLocale: const Locale('ko'),
          startLocale: const Locale('ko'),
          child: Builder(
            builder: (context) => MaterialApp(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              home: TimeUpOverlay(game: game),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('게임 점수 결과'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(TimeUpOverlay)),
    );
    expect(container.read(rankingProvider), const RankingSubmitState());
    expect(tester.takeException(), isNull);
  });
}
