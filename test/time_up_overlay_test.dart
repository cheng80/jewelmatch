import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/ads/ad_reward_policy.dart';
import 'package:stonematch/ads/fake_ad_service.dart';
import 'package:stonematch/game/jewel_game_mode.dart';
import 'package:stonematch/game/match_board_game.dart';
import 'package:stonematch/services/ranking_service.dart';
import 'package:stonematch/views/overlays/time_up_overlay.dart';
import 'package:stonematch/vm/ranking_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('empty progression result stays out of ranking', (tester) async {
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
              home: TimeUpOverlay(
                game: game,
                adService: FakeAdService(),
                adRewardPolicy: AdRewardPolicy(),
              ),
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

  testWidgets('failed ranking submission can retry the same score', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final game = MatchBoardGame(gameMode: JewelGameMode.timed)
      ..board.score = 1234;
    late _RetryRankingNotifier notifier;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rankingProvider.overrideWith(
            () => notifier = _RetryRankingNotifier(),
          ),
        ],
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
              home: TimeUpOverlay(
                game: game,
                adService: FakeAdService(),
                adRewardPolicy: AdRewardPolicy(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(notifier.calls, 1);
    expect(find.byTooltip('랭킹 기록 다시 제출'), findsOneWidget);

    await tester.tap(find.byTooltip('랭킹 기록 다시 제출'));
    await tester.pumpAndSettle();

    expect(notifier.calls, 2);
    expect(notifier.mode, RankingMode.time);
    expect(notifier.score, 1234);
    expect(find.byTooltip('랭킹 기록 다시 제출'), findsNothing);
  });
}

class _RetryRankingNotifier extends RankingNotifier {
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
    required String trIntossLevelRankSubmitFailed,
  }) async {
    calls++;
    this.mode = mode;
    this.score = score;
    state = calls == 1
        ? RankingSubmitState(rankMessage: trRankSubmitFailed)
        : RankingSubmitState(submitted: true, rankMessage: trRankNotInTop);
  }
}

class _TestAssetLoader extends AssetLoader {
  const _TestAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => {
    'timeUpTitle': '시간 종료',
    'gameResult': '게임 점수 결과',
    'retry': '다시하기',
    'statsButton': '통계',
    'exit': '나가기',
    'rankSuccess': '랭킹 성공',
    'rankLevelSuccess': '레벨 랭킹 성공',
    'rankNotInTop': '순위 밖',
    'rankNotFound': '랭킹 없음',
    'rankLoadFailed': '랭킹 조회 실패',
    'rankSaveFailed': '랭킹 저장 실패',
    'rankSubmitFailed': '랭킹 서버에 연결할 수 없습니다',
    'rankRetrySubmit': '랭킹 기록 다시 제출',
    'intossLevelRankSubmitFailed': '앱인토스 제출 실패',
  };
}
