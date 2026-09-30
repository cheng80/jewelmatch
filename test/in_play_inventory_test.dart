import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stonematch/ads/ad_reward_policy.dart';
import 'package:stonematch/ads/fake_ad_service.dart';
import 'package:stonematch/game/components/match_game_hud.dart';
import 'package:stonematch/game/item_kind.dart';
import 'package:stonematch/game/jewel_game_mode.dart';
import 'package:stonematch/game/match_board_game.dart';
import 'package:stonematch/resources/texture_atlas.dart';
import 'package:stonematch/services/game_settings.dart';
import 'package:stonematch/utils/storage_helper.dart';
import 'package:stonematch/views/overlays/stage_inventory_overlay.dart';
import 'package:stonematch/widgets/atlas_image.dart';

MatchBoardGame fixture([JewelGameMode mode = JewelGameMode.progression]) {
  final game = MatchBoardGame(gameMode: mode);
  for (final name in ['IntroBlock', 'StageInventory', 'LevelUp', 'PauseMenu']) {
    game.overlays.addEntry(name, (_, _) => const SizedBox());
  }
  game.onGameResize(Vector2(390, 750));
  game.board
    ..introFillInProgress = false
    ..inputLocked = false
    ..state = 'idle';
  return game;
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageHelper.init();
    GameSettings.sfxMuted = true;
    GameSettings.bgmMuted = true;
    for (final name in [
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers.global',
    ]) {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        MethodChannel(name),
        (_) async => null,
      );
    }
  });

  test('열기 시 시간과 입력 정지, 취소 시 장착과 수량 유지 후 재개', () {
    final game = fixture()..timeRemaining = 42;
    game.runInventory.add(ItemKind.thorHammer);
    final loadout = game.stageLoadout;
    final counts = game.runInventory.snapshot();
    game.showStageInventory();
    expect(game.isInPlayInventoryOpen, isTrue);
    expect(game.isPlaying, isFalse);
    expect(game.paused, isTrue);
    expect(game.canUseTestItem(ItemKind.runeHammer), isFalse);
    game.handleBoardTap(50, 250);
    expect(game.board.selected, isNull);
    game.update(5);
    expect(game.timeRemaining, 42);
    expect(game.assignNextStageLoadoutSlot(0, ItemKind.thorHammer), isTrue);
    expect(game.stageLoadout, same(loadout));
    game.closeStageInventory();
    expect(game.stageLoadout, same(loadout));
    expect(game.nextStageLoadoutDraft, same(loadout));
    expect(game.runInventory.snapshot(), counts);
    expect(game.isPlaying, isTrue);
    expect(game.paused, isFalse);
    game.update(1);
    expect(game.timeRemaining, 41);
  });

  test('적용은 현재와 다음 레벨 장착에 반영하며 소모는 실제 사용 시 발생', () {
    final game = fixture();
    game.runInventory.add(ItemKind.thorHammer);
    final counts = game.runInventory.snapshot();
    game.showStageInventory();
    game.assignNextStageLoadoutSlot(1, ItemKind.thorHammer);
    expect(game.assignNextStageLoadoutSlot(2, ItemKind.thorHammer), isFalse);
    expect(game.assignNextStageLoadoutSlot(0, ItemKind.hyperCube), isFalse);
    game.closeStageInventory(apply: true);
    expect(game.stageLoadout.slots[1].item, ItemKind.thorHammer);
    expect(game.nextStageLoadoutDraft, same(game.stageLoadout));
    expect(game.runInventory.snapshot(), counts);
    expect(game.canUseTestItem(ItemKind.thorHammer), isTrue);
    expect(game.canUseTestItem(ItemKind.ancientBomb), isFalse);
    game.closeStageInventory(); // 중복 닫기 무시
    expect(game.stageLoadout.slots[1].item, ItemKind.thorHammer);
  });

  test('타임과 무한 모드, 낙하와 입력 잠금, 일시정지 중에는 열지 않는다', () {
    for (final mode in [JewelGameMode.timed, JewelGameMode.simple]) {
      final game = fixture(mode);
      game.showStageInventory();
      expect(game.overlays.isActive('StageInventory'), isFalse);
      expect(game.isPlaying, isTrue);
    }
    final game = fixture();
    game.board.state = 'falling';
    game.showStageInventory();
    expect(game.isInPlayInventoryOpen, isFalse);
    game.board.state = 'idle';
    game.board.inputLocked = true;
    game.showStageInventory();
    expect(game.isInPlayInventoryOpen, isFalse);
    game.board.inputLocked = false;
    game.board.introFillInProgress = true;
    game.showStageInventory();
    expect(game.isInPlayInventoryOpen, isFalse);
    game.board.introFillInProgress = false;
    game.isPlaying = false;
    game.showStageInventory();
    expect(game.overlays.isActive('StageInventory'), isFalse);
  });

  test('결과창 인벤토리 닫기는 편집안을 유지하고 게임을 재개하지 않는다', () {
    final game = fixture()..isPlaying = false;
    game.pauseEngine();
    game.overlays.add('LevelUp');
    game.runInventory.add(ItemKind.thorHammer);
    game.showStageInventory();
    expect(game.isInPlayInventoryOpen, isFalse);
    game.assignNextStageLoadoutSlot(0, ItemKind.thorHammer);
    game.closeStageInventory();
    expect(game.nextStageLoadoutDraft.slots[0].item, ItemKind.thorHammer);
    expect(game.stageLoadout.slots[0].item, ItemKind.runeHammer);
    expect(game.overlays.isActive('LevelUp'), isTrue);
    expect(game.isPlaying, isFalse);
    expect(game.paused, isTrue);
  });

  test('백그라운드 닫기는 PauseMenu로 돌아가고 재시작 뒤 닫기는 무시', () {
    final game = fixture();
    game.showStageInventory();
    game.lifecycleStateChange(AppLifecycleState.hidden);
    game.closeStageInventory(apply: true);
    expect(game.overlays.isActive('PauseMenu'), isTrue);
    expect(game.isPlaying, isFalse);
    expect(game.paused, isTrue);
    game.lifecycleStateChange(AppLifecycleState.resumed);
    game.resumeGame();
    expect(game.isPlaying, isTrue);
    game.showStageInventory();
    game.restartRound();
    final loadout = game.stageLoadout;
    game.closeStageInventory(apply: true);
    expect(game.isInPlayInventoryOpen, isFalse);
    expect(game.stageLoadout, same(loadout));
    expect(game.isPlaying, isTrue);
  });

  test('얇은 하단 패널에서 4슬롯과 인벤토리는 한 줄이며 프레임이 겹치지 않는다', () {
    for (final width in [320.0, 375.0, 430.0]) {
      for (final mode in JewelGameMode.values) {
        final game = fixture(mode)..onGameResize(Vector2(width, 750));
        final hud = MatchGameHud(
          onPausePressed: () {},
          onHintPressed: () {},
          onTutorialPressed: () {},
          onRankingPressed: mode == JewelGameMode.timed ? () {} : null,
        )..game = game;
        hud.onGameResize(game.size);
        final buttons = hud.debugReadButtonRects();
        final bag = buttons['inventory']!;
        expect(bag.isEmpty, mode != JewelGameMode.progression);
        if (!bag.isEmpty) {
          for (final key in ['pause', 'hint', 'tutorial', 'ranking']) {
            expect(bag.overlaps(buttons[key]!), isFalse);
          }
          expect(bag.overlaps(game.boardFrameRect), isFalse);
          final tray = hud.debugReadAlignedHudRects()['itemTray']!;
          expect(tray.contains(bag.topLeft), isTrue);
          expect(tray.contains(bag.bottomRight), isTrue);
          expect(bag.width, 40);
          expect(tray.height, lessThan(86));
          for (final slot in hud.debugReadLoadoutSlotRects().values) {
            expect(slot.center.dy, closeTo(bag.center.dy, .001));
            expect(slot.right, lessThan(bag.left - 10));
            expect(tray.contains(slot.topLeft), isTrue);
            expect(tray.contains(slot.bottomRight), isTrue);
            expect(
              bag
                  .inflate(bag.width * .08)
                  .overlaps(slot.inflate(slot.width * .08)),
              isFalse,
            );
          }
          expect(bag.height, greaterThanOrEqualTo(24));
          expect(hud.debugTapButton(bag.center), isTrue);
          expect(game.isInPlayInventoryOpen, isTrue);
          expect(bag.right, lessThanOrEqualTo(width));
        }
      }
    }
  });

  for (final action in ['apply', 'escape', 'back', 'cancel']) {
    final apply = action == 'apply';
    testWidgets('실제 인벤토리 선택과 $action', (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final game = fixture();
      game.runInventory.add(ItemKind.thorHammer);
      game.showStageInventory();
      await tester.pumpWidget(
        EasyLocalization(
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
              home: Scaffold(
                body: StageInventoryOverlay(
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
      expect(find.text('현재 장착 아이템'), findsOneWidget);
      final item = find.byWidgetPredicate(
        (w) => w is AtlasImage && w.frame == UiFrames.itemThorHammer,
      );
      await tester.tap(
        find.ancestor(of: item, matching: find.byType(GestureDetector)).first,
      );
      await tester.pumpAndSettle();
      expect(game.nextStageLoadoutDraft.slots[0].item, ItemKind.thorHammer);
      if (apply) {
        await tester.ensureVisible(find.text('적용하고 계속'));
        await tester.tap(find.text('적용하고 계속'));
      } else if (action == 'escape') {
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      } else if (action == 'back') {
        await binding.handlePopRoute();
      } else {
        await tester.ensureVisible(find.text('취소'));
        await tester.tap(find.text('취소'));
      }
      await tester.pumpAndSettle();
      expect(game.isInPlayInventoryOpen, isFalse);
      expect(game.isPlaying, isTrue);
      expect(
        game.stageLoadout.slots[0].item,
        apply ? ItemKind.thorHammer : ItemKind.runeHammer,
      );
      expect(game.runInventory.quantityOf(ItemKind.thorHammer), 1);
      expect(tester.takeException(), isNull);
    });
  }
}

class _TestAssetLoader extends AssetLoader {
  const _TestAssetLoader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('$path/ko.json').readAsStringSync())
          as Map<String, dynamic>;
}
