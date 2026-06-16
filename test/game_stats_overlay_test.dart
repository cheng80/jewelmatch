import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/game/jewel_game_mode.dart';
import 'package:stonematch/game/match_board_game.dart';
import 'package:stonematch/game/match_board_logic.dart';
import 'package:stonematch/views/overlays/game_stats_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('game stats overlay shows current round counters', (
    tester,
  ) async {
    final game = MatchBoardGame(gameMode: JewelGameMode.simple);
    game.board.score = 12345;
    game.board.stats
      ..recordValidSwap()
      ..recordMatchGroups(2)
      ..recordGemRemoved(GemKind.normal)
      ..recordGemRemoved(GemKind.bomb)
      ..recordSpecialCreated(GemKind.star)
      ..recordSpecialActivated(GemKind.bomb);

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
            home: GameStatsOverlay(game: game),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('게임 통계'), findsOneWidget);
    expect(find.text('점수'), findsOneWidget);
    expect(find.text('12,345'), findsOneWidget);
    expect(find.text('유효 스왑'), findsOneWidget);
    expect(find.text('매치 그룹'), findsOneWidget);
    expect(find.text('제거한 보석'), findsOneWidget);
    expect(find.text('특수 생성 내역'), findsOneWidget);
    expect(find.text('특수 발동 내역'), findsOneWidget);
    expect(find.text('닫기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
