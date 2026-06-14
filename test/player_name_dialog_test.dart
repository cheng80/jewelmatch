import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jewelmatch/services/game_settings.dart';
import 'package:jewelmatch/utils/storage_helper.dart';
import 'package:jewelmatch/views/title/player_name_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageHelper.init();
    await StorageHelper.erase();
    GameSettings.playerName = 'GUEST';
  });

  testWidgets('player name dialog does not reuse controller after submit', (
    tester,
  ) async {
    String? result;
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
            home: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () async {
                    result = await showPlayerNameDialog(context);
                  },
                  child: const Text('open'),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'MAGE');
    await tester.tap(find.text('시작'));
    await tester.pump();

    expect(tester.takeException(), isNull);

    await tester.pumpAndSettle();

    expect(result, 'MAGE');
  });
}
