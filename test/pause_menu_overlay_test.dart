import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jewelmatch/game/jewel_game_mode.dart';
import 'package:jewelmatch/game/match_board_game.dart';
import 'package:jewelmatch/utils/storage_helper.dart';
import 'package:jewelmatch/views/overlays/pause_menu_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageHelper.init();
    await StorageHelper.erase();
  });

  testWidgets(
    'pause menu sliders can be dragged without overlay owner errors',
    (tester) async {
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

      final firstSlider = find.byType(Slider).first;
      await tester.drag(firstSlider, const Offset(70, 0));
      await tester.pump();

      expect(tester.takeException(), isNull);
    },
  );
}
