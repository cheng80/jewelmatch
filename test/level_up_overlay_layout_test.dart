import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stonematch/game/item_inventory.dart';
import 'package:stonematch/game/item_kind.dart';
import 'package:stonematch/game/jewel_game_mode.dart';
import 'package:stonematch/game/match_board_game.dart';
import 'package:stonematch/game/stage_reward.dart';
import 'package:stonematch/services/game_settings.dart';
import 'package:stonematch/utils/storage_helper.dart';
import 'package:stonematch/views/overlays/level_up_overlay.dart';
import 'package:stonematch/views/overlays/stage_inventory_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('level up overlay uses two reward columns for six rewards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 690);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    await StorageHelper.init();
    await StorageHelper.erase();
    GameSettings.sfxMuted = true;

    final game = MatchBoardGame(gameMode: JewelGameMode.progression)
      ..levelUpFromLevel = 1
      ..levelUpToLevel = 2
      ..latestStageRewards = const [
        StageRewardGrant(
          item: ItemKind.runeHammer,
          quantity: 1,
          reasonKey: 'test',
        ),
        StageRewardGrant(
          item: ItemKind.ancientBomb,
          quantity: 1,
          reasonKey: 'test',
        ),
        StageRewardGrant(
          item: ItemKind.thorHammer,
          quantity: 1,
          reasonKey: 'test',
        ),
        StageRewardGrant(
          item: ItemKind.hyperCube,
          quantity: 1,
          reasonKey: 'test',
        ),
        StageRewardGrant(
          item: ItemKind.prismTransform,
          quantity: 1,
          reasonKey: 'test',
        ),
        StageRewardGrant(
          item: ItemKind.fateShuffle,
          quantity: 1,
          reasonKey: 'test',
        ),
      ];

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
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.25)),
              child: Scaffold(body: LevelUpOverlay(game: game)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final exception = tester.takeException();
    if (exception is FlutterError) {
      fail(exception.toStringDeep());
    }
    expect(exception, isNull);

    final first = tester.getTopLeft(find.text('룬 망치'));
    final second = tester.getTopLeft(find.text('고대 폭탄'));
    final third = tester.getTopLeft(find.text('토르 망치'));
    final prismLabel = find.text('프리즘 변환');
    final prismLabelRect = tester.getRect(prismLabel);
    final quantityRects = [
      for (final element in find.text('x1').evaluate())
        tester.getRect(
          find.byElementPredicate((candidate) => identical(candidate, element)),
        ),
    ];

    expect(second.dx, greaterThan(first.dx));
    expect((second.dy - first.dy).abs(), lessThan(1));
    expect((third.dx - first.dx).abs(), lessThan(1));
    expect(third.dy, greaterThan(first.dy));
    expect(prismLabel, findsOneWidget);
    expect(find.text('x1'), findsNWidgets(6));
    expect(
      quantityRects.any(
        (rect) =>
            rect.top >= prismLabelRect.bottom - 1 &&
            (rect.left - prismLabelRect.left).abs() < 1,
      ),
      isTrue,
    );
  });

  testWidgets('stage inventory overlay does not overflow on narrow phones', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 690);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    await StorageHelper.init();
    await StorageHelper.erase();
    GameSettings.sfxMuted = true;

    final game = MatchBoardGame(gameMode: JewelGameMode.progression)
      ..stageLoadoutOpenSlotCount = StageLoadout.phase2SlotCount
      ..stageLoadout = StageLoadout.fromOpenItems([
        ItemKind.runeHammer,
        ItemKind.ancientBomb,
        null,
        null,
      ], openSlotCount: StageLoadout.phase2SlotCount)
      ..nextStageLoadoutDraft = StageLoadout.fromOpenItems([
        ItemKind.runeHammer,
        ItemKind.ancientBomb,
        null,
        null,
      ], openSlotCount: StageLoadout.phase2SlotCount);
    for (final item in ItemKind.values) {
      game.runInventory.add(item);
    }

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
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.25)),
              child: Scaffold(body: StageInventoryOverlay(game: game)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
