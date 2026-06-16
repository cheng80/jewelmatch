import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/game/jewel_game_mode.dart';
import 'package:stonematch/game/match_board_game.dart';
import 'package:stonematch/utils/storage_helper.dart';
import 'package:stonematch/views/overlays/pause_menu_overlay.dart';
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
}
