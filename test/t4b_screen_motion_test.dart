import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stonematch/ads/ad_reward_policy.dart';
import 'package:stonematch/ads/ad_service.dart';
import 'package:stonematch/ads/fake_ad_service.dart';
import 'package:stonematch/game/item_inventory.dart';
import 'package:stonematch/game/item_kind.dart';
import 'package:stonematch/game/jewel_game_mode.dart';
import 'package:stonematch/game/match_board_game.dart';
import 'package:stonematch/game/stage_reward.dart';
import 'package:stonematch/resources/asset_paths.dart';
import 'package:stonematch/services/game_settings.dart';
import 'package:stonematch/services/ranking_service.dart';
import 'package:stonematch/utils/storage_helper.dart';
import 'package:stonematch/views/overlays/game_loading_overlay.dart';
import 'package:stonematch/views/overlays/level_celebration_overlay.dart';
import 'package:stonematch/views/overlays/level_up_overlay.dart';
import 'package:stonematch/views/overlays/stage_inventory_overlay.dart';
import 'package:stonematch/views/overlays/time_up_overlay.dart';
import 'package:stonematch/vm/ranking_notifier.dart';
import 'package:stonematch/widgets/overlay_motion.dart';
import 'package:stonematch/widgets/ranking_list_popup.dart';

Future<void> _mount(
  WidgetTester tester,
  Widget child, {
  bool reduced = false,
  _RecordingRanking? ranking,
  GoRouter? router,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (ranking != null) rankingProvider.overrideWith(() => ranking),
      ],
      child: EasyLocalization(
        supportedLocales: const [Locale('ko')],
        path: 'assets/translations',
        assetLoader: const _AssetLoader(),
        fallbackLocale: const Locale('ko'),
        startLocale: const Locale('ko'),
        child: Builder(
          builder: (context) {
            Widget wrap(BuildContext context, Widget? child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: child!,
            );
            if (router != null) {
              return MaterialApp.router(
                routerConfig: router,
                builder: wrap,
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                locale: context.locale,
              );
            }
            return MaterialApp(
              builder: wrap,
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              home: Scaffold(body: child),
            );
          },
        ),
      ),
    ),
  );
  // Complete localization before starting the animation clock.
  for (var i = 0; i < 10; i++) {
    await tester.pump();
  }
}

Finder itemImage(String path) => find.byWidgetPredicate(
  (w) =>
      w is Image &&
      w.image is AssetImage &&
      (w.image as AssetImage).assetName == 'assets/images/$path',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageHelper.init();
    await StorageHelper.erase();
    GameSettings.sfxMuted = true;
    GameSettings.bgmMuted = true;
  });

  for (final reduced in [false, true]) {
    testWidgets(
      'time up retains 1900ms submission and final score, reduced=$reduced',
      (tester) async {
        final game = _ScreenGame(JewelGameMode.timed)..board.score = 1234;
        final ranking = _RecordingRanking();
        await _mount(
          tester,
          TimeUpOverlay(
            game: game,
            adService: FakeAdService(),
            adRewardPolicy: AdRewardPolicy(),
            previousBestScore: 1000,
          ),
          reduced: reduced,
          ranking: ranking,
        );
        expect(ranking.calls, 0);
        if (reduced) expect(find.text('1234'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 1899));
        expect(ranking.calls, 0);
        await tester.pump(const Duration(milliseconds: 1));
        expect(ranking.calls, 1);
        expect(ranking.score, 1234);
        await tester.pumpAndSettle();
        expect(find.text('1234'), findsOneWidget);
        expect(find.byIcon(Icons.star_rounded), findsOneWidget);
        await tester.pump(const Duration(seconds: 3));
        expect(ranking.calls, 1);
        expect(game.board.score, 1234);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('reward order and final state, reduced=$reduced', (
      tester,
    ) async {
      final game = _ScreenGame(JewelGameMode.progression)
        ..latestStageRewards = const [
          StageRewardGrant(
            item: ItemKind.runeHammer,
            quantity: 1,
            reasonKey: 'test',
          ),
          StageRewardGrant(
            item: ItemKind.ancientBomb,
            quantity: 2,
            reasonKey: 'test',
          ),
        ];
      final inventory = game.runInventory.snapshot();
      await _mount(tester, LevelUpOverlay(game: game), reduced: reduced);
      final fades = find.descendant(
        of: find.byType(StaggerReveal),
        matching: find.byType(FadeTransition),
      );
      expect(
        tester
            .widgetList<FadeTransition>(fades)
            .every((w) => w.opacity.value == 1),
        reduced,
      );
      await tester.pump(const Duration(milliseconds: 35));
      final values = tester
          .widgetList<FadeTransition>(fades)
          .map((w) => w.opacity.value)
          .toList();
      if (!reduced) {
        expect(values.first, greaterThan(0));
        expect(values.last, 0);
      }
      await tester.pumpAndSettle();
      expect(find.text('x1'), findsOneWidget);
      expect(find.text('x2'), findsOneWidget);
      expect(game.runInventory.snapshot(), inventory);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'inventory equips immediately, locks stay locked, reduced=$reduced',
      (tester) async {
        final game = _ScreenGame(JewelGameMode.progression)
          ..nextStageLoadoutDraft = StageLoadout.fromOpenItems([null, null]);
        await _mount(
          tester,
          StageInventoryOverlay(
            game: game,
            adService: FakeAdService(),
            adRewardPolicy: AdRewardPolicy(),
          ),
          reduced: reduced,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.lock_rounded).first);
        await tester.tap(
          find
              .ancestor(
                of: itemImage(AssetPaths.itemIconRuneHammer),
                matching: find.byType(GestureDetector),
              )
              .first,
        );
        expect(
          game.nextStageLoadoutDraft.slots.first.item,
          ItemKind.runeHammer,
        );
        expect(game.nextStageLoadoutDraft.slots[2].locked, isTrue);
        expect(game.runInventory.quantityOf(ItemKind.runeHammer), 1);
        await tester.pump();
        final scales = tester.widgetList<ScaleTransition>(
          find.descendant(
            of: find.byType(StageInventoryOverlay),
            matching: find.byType(ScaleTransition),
          ),
        );
        if (reduced) {
          expect(scales.map((w) => w.scale.value).toList(), everyElement(1));
        } else {
          expect(scales.any((w) => w.scale.value > 1), isTrue);
        }
        await tester.pumpAndSettle();
        expect(itemImage(AssetPaths.itemIconRuneHammer), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'celebration completes once with motion preference, reduced=$reduced',
      (tester) async {
        final game = _ScreenGame(JewelGameMode.progression);
        game.overlays.addEntry('LevelCelebration', (_, _) => const SizedBox());
        game.overlays.add('LevelCelebration');
        game.isPlaying = false;
        game.pauseEngine();
        await _mount(
          tester,
          LevelCelebrationOverlay(game: game),
          reduced: reduced,
        );
        if (reduced) {
          expect(game.celebrations, 1);
        } else {
          await tester.pump(const Duration(milliseconds: 2999));
          expect(game.celebrations, 0);
          await tester.pump(const Duration(milliseconds: 1));
          expect(game.celebrations, 1);
        }
        await tester.pumpAndSettle();
        expect(game.celebrations, 1);
      },
    );

    testWidgets('loading keeps moving past 1.2s, reduced=$reduced', (
      tester,
    ) async {
      await _mount(
        tester,
        const GameLoadingOverlay(gameMode: JewelGameMode.timed),
        reduced: reduced,
      );
      // 로딩 해제는 1.2초를 넘길 수 있다. 그 뒤에도 움직여야 먹통으로 보이지 않는다.
      await tester.pump(const Duration(milliseconds: 1300));
      expect(find.text('불러오는 중...'), findsOneWidget);
      if (reduced) {
        await tester.pumpAndSettle();
        expect(tester.binding.transientCallbackCount, 0);
      } else {
        expect(tester.binding.transientCallbackCount, greaterThan(0));
      }
    });
  }

  for (final result in [
    RewardedAdResult.rewarded,
    RewardedAdResult.dismissed,
  ]) {
    testWidgets('refill feedback matches actual grant: $result', (
      tester,
    ) async {
      final game = _ScreenGame(JewelGameMode.progression);
      final ads = FakeAdService(nextResult: result);
      final policy = AdRewardPolicy();
      unawaited(ads.preloadRewarded());
      await tester.pump(const Duration(milliseconds: 120));
      await _mount(
        tester,
        StageInventoryOverlay(
          game: game,
          adService: ads,
          adRewardPolicy: policy,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .ancestor(
              of: itemImage(AssetPaths.itemIconThorHammer),
              matching: find.byType(GestureDetector),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(OutlinedButton).first);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      final success = result == RewardedAdResult.rewarded;
      expect(
        game.runInventory.quantityOf(ItemKind.thorHammer),
        success ? 1 : 0,
      );
      expect(
        tester.widget<AdResultBanner>(find.byType(AdResultBanner)).success,
        success,
      );
      expect(policy.remainingRefillsToday, success ? 2 : 3);
      expect(tester.takeException(), isNull);
      ads.dispose();
    });

    testWidgets('continue feedback never grants twice: $result', (
      tester,
    ) async {
      final game = _ScreenGame(JewelGameMode.progression);
      final ads = FakeAdService(nextResult: result);
      final policy = AdRewardPolicy();
      unawaited(ads.preloadRewarded());
      await tester.pump(const Duration(milliseconds: 120));
      await _mount(
        tester,
        TimeUpOverlay(game: game, adService: ads, adRewardPolicy: policy),
        ranking: _RecordingRanking(),
      );
      await tester.pump(const Duration(milliseconds: 1900));
      await tester.pumpAndSettle();
      final watch = find.text('광고 보고 이어하기');
      expect(watch, findsOneWidget);
      await tester.tap(watch);
      await tester.tap(watch);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      final success = result == RewardedAdResult.rewarded;
      expect(game.continues, success ? 1 : 0);
      expect(policy.canContinueStage(game.stageAttemptId), !success);
      expect(
        tester.widget<AdResultBanner>(find.byType(AdResultBanner)).success,
        success,
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      ads.dispose();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'reduced motion cannot restart before the original submission point',
    (tester) async {
      final game = _ScreenGame(JewelGameMode.timed)..board.score = 1234;
      final ranking = _RecordingRanking();
      await _mount(
        tester,
        TimeUpOverlay(
          game: game,
          adService: FakeAdService(),
          adRewardPolicy: AdRewardPolicy(),
        ),
        reduced: true,
        ranking: ranking,
      );
      await tester.tap(find.text('다시하기'), warnIfMissed: false);
      expect(game.restarts, 0);
      await tester.pump(const Duration(milliseconds: 1900));
      expect(ranking.score, 1234);
      await tester.tap(find.text('다시하기'));
      expect(game.restarts, 1);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'reduced time up rejects keyboard and semantics until submission',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final game = _ScreenGame(JewelGameMode.timed)..board.score = 1234;
      final ranking = _RecordingRanking();
      await _mount(
        tester,
        TimeUpOverlay(
          game: game,
          adService: FakeAdService(),
          adRewardPolicy: AdRewardPolicy(),
        ),
        reduced: true,
        ranking: ranking,
      );
      final buttonSemantics = tester.getSemantics(find.text('다시하기'));
      expect(
        buttonSemantics.getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse,
      );
      for (var i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
      }
      expect(game.restarts, 0);
      await tester.pump(const Duration(milliseconds: 1900));
      expect(ranking.score, 1234);
      expect(
        tester
            .getSemantics(find.text('다시하기'))
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
      await tester.tap(find.text('다시하기'));
      expect(game.restarts, 1);
      await tester.pumpAndSettle();
      semantics.dispose();
    },
  );

  testWidgets('ranking placeholders settle then show completed data', (
    tester,
  ) async {
    final result = Completer<RankingResult<List<RankingEntry>>>();
    await _mount(
      tester,
      RankingListPopup(
        onClose: () {},
        levelFuture: result.future,
        timeFuture: result.future,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNWidgets(3));
    result.complete(const RankingResult.success([]));
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('time up exit does not await an in-flight ranking request', (
    tester,
  ) async {
    final ranking = _RecordingRanking()..pending = Completer<void>();
    final game = _ScreenGame(JewelGameMode.timed)..board.score = 100;
    final router = GoRouter(
      initialLocation: '/game',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('title')),
        GoRoute(
          path: '/game',
          builder: (_, _) => TimeUpOverlay(
            game: game,
            adService: FakeAdService(),
            adRewardPolicy: AdRewardPolicy(),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await _mount(
      tester,
      const SizedBox.shrink(),
      router: router,
      ranking: ranking,
    );
    await tester.pump(const Duration(milliseconds: 1900));
    await tester.pump(const Duration(seconds: 1));
    expect(ranking.calls, 1);
    await tester.tap(find.text('나가기'));
    await tester.pumpAndSettle();
    expect(find.text('title'), findsOneWidget);
    expect(ranking.pending!.isCompleted, isFalse);
    ranking.pending!.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  for (final record in [
    (2, 5000, false),
    (3, 1000, false),
    (3, 1001, true),
    (4, 0, true),
  ]) {
    testWidgets('best record compares level before score: $record', (
      tester,
    ) async {
      final game = _ScreenGame(JewelGameMode.progression)
        ..progressionLevel = record.$1
        ..board.score = record.$2;
      await _mount(
        tester,
        TimeUpOverlay(
          game: game,
          previousBestLevel: 3,
          previousBestScore: 1000,
          adService: FakeAdService(),
          adRewardPolicy: AdRewardPolicy(),
        ),
        reduced: true,
        ranking: _RecordingRanking(),
      );
      expect(
        find.byIcon(Icons.star_rounded),
        record.$3 ? findsOneWidget : findsNothing,
      );
      await tester.pump(const Duration(milliseconds: 1900));
      await tester.pumpAndSettle();
    });
  }
}

class _ScreenGame extends MatchBoardGame {
  _ScreenGame(JewelGameMode mode) : super(gameMode: mode);
  int continues = 0;
  int restarts = 0;
  @override
  void restartRound() {
    restarts++;
  }

  int celebrations = 0;
  @override
  bool continueStageAfterAd() {
    continues++;
    return true;
  }

  @override
  void showLevelUpPopupAfterCelebration() {
    celebrations++;
  }
}

class _RecordingRanking extends RankingNotifier {
  int calls = 0;
  int? score;
  Completer<void>? pending;
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
    this.score = score;
    if (pending != null) await pending!.future;
  }
}

class _AssetLoader extends AssetLoader {
  const _AssetLoader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('$path/ko.json').readAsStringSync())
          as Map<String, dynamic>;
}
