import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/game/jewel_game_mode.dart';
import 'package:stonematch/game/match_board_game.dart';
import 'package:stonematch/views/overlays/no_moves_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('no moves overlay paints with obsidian fantasy frame', (
    tester,
  ) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('ko')],
        path: 'assets/translations',
        fallbackLocale: const Locale('ko'),
        startLocale: const Locale('ko'),
        child: Builder(
          builder: (context) => MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            home: NoMovesOverlay(
              game: MatchBoardGame(gameMode: JewelGameMode.simple),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('더 이상 이동할 수\n없습니다'), findsOneWidget);
    expect(find.text('셔플'), findsOneWidget);
    expect(find.text('새 보드'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
