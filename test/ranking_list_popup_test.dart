import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/app_config.dart';
import 'package:stonematch/services/ranking_service.dart';
import 'package:stonematch/widgets/ranking_list_popup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Apps in Toss alone shows the level leaderboard notice', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 750));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final empty = Future.value(
      const RankingResult<List<RankingEntry>>.success([]),
    );

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
            home: Scaffold(
              body: RankingListPopup(
                levelFuture: empty,
                timeFuture: empty,
                onClose: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final isIntoss = AppConfig.storeChannel == StoreChannel.intoss;
    expect(
      find.text('앱인토스 랭킹에는 레벨 모드 기록만 제출돼요.'),
      isIntoss ? findsOneWidget : findsNothing,
    );
    expect(
      find.text('앱인토스 레벨 랭킹 보기'),
      isIntoss ? findsOneWidget : findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
