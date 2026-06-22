import 'package:flame/components.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stonematch/game/item_kind.dart';
import 'package:stonematch/game/jewel_game_mode.dart';
import 'package:stonematch/game/match_board_game.dart';
import 'package:stonematch/game/match_board_logic.dart';
import 'package:stonematch/services/game_settings.dart';
import 'package:stonematch/utils/storage_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('MatchBoardGame simple / timed', () {
    final simple = MatchBoardGame(gameMode: JewelGameMode.simple);
    final progression = MatchBoardGame(gameMode: JewelGameMode.progression);
    final timed = MatchBoardGame(gameMode: JewelGameMode.timed);
    expect(simple.isTimedMode, false);
    expect(progression.isProgressionMode, true);
    expect(progression.isTimedMode, false);
    expect(timed.isTimedMode, true);
    expect(JewelGameMode.fromQuery('progression'), JewelGameMode.progression);
    expect(MatchBoardGame.rows, 8);
    expect(MatchBoardGame.cols, 8);
  });

  test(
    'MatchBoardGame requestHint cycles through shuffled board hints',
    () async {
      SharedPreferences.setMockInitialValues({});
      await StorageHelper.init();
      await StorageHelper.erase();
      GameSettings.sfxMuted = true;
      final game = MatchBoardGame(gameMode: JewelGameMode.simple);
      _setRows(game.board, _validMoveRows);
      final moves = game.board.getAllValidMoves();

      expect(moves.length, greaterThan(1));
      final firstCycle = <String>[];
      for (var index = 0; index < moves.length; index++) {
        game.requestHint();
        final hint = _hintKey(game.board);

        expect(_moveKeys(moves), contains(hint));
        firstCycle.add(hint);
      }
      expect(firstCycle.toSet(), hasLength(moves.length));

      game.requestHint();

      expect(_hintKey(game.board), firstCycle.first);
    },
  );

  test('hint limits apply only to timed and progression modes', () async {
    SharedPreferences.setMockInitialValues({});
    await StorageHelper.init();
    await StorageHelper.erase();
    GameSettings.sfxMuted = true;

    final simple = MatchBoardGame(gameMode: JewelGameMode.simple);
    final timed = MatchBoardGame(gameMode: JewelGameMode.timed);
    final progression = MatchBoardGame(gameMode: JewelGameMode.progression);
    for (final game in [simple, timed, progression]) {
      _setHintBoard(game.board);
    }

    expect(simple.hintBadgeCount, isNull);
    expect(timed.hintBadgeCount, 3);
    expect(progression.hintBadgeCount, 2);

    simple.requestHint();
    expect(simple.hintBadgeCount, isNull);
    expect(simple.board.hintCellA, isNotNull);

    timed.requestHint();
    timed.requestHint();
    timed.requestHint();
    expect(timed.hintBadgeCount, 0);
    expect(timed.board.hintCellA, isNotNull);
    timed.board.clearHint();
    timed.requestHint();
    expect(timed.hintBadgeCount, 0);
    expect(timed.board.hintCellA, isNull);

    progression.requestHint();
    expect(progression.hintBadgeCount, 1);
    progression.levelUpToLevel = 2;
    progression.overlays.addEntry(
      'IntroBlock',
      (_, _) => const SizedBox.shrink(),
    );
    progression.continueAfterLevelUp();
    expect(progression.hintBadgeCount, 2);
  });

  test('item loadout slots show test items in simple mode', () {
    final simple = MatchBoardGame(gameMode: JewelGameMode.simple);
    final timed = MatchBoardGame(gameMode: JewelGameMode.timed);
    final progression = MatchBoardGame(gameMode: JewelGameMode.progression);

    expect(
      simple.hudLoadoutSlots,
      hasLength(ItemKindMeta.phaseOneLoadout.length),
    );
    expect(
      simple.hudLoadoutSlots.map((slot) => slot.item),
      ItemKindMeta.phaseOneLoadout,
    );
    expect(timed.hudLoadoutSlots, isEmpty);
    expect(progression.hudLoadoutSlots, hasLength(4));
  });

  test(
    'round start intro is released after loading for every game mode',
    () async {
      SharedPreferences.setMockInitialValues({});
      await StorageHelper.init();
      await StorageHelper.erase();
      GameSettings.sfxMuted = true;

      for (final mode in JewelGameMode.values) {
        final game = MatchBoardGame(gameMode: mode);
        game.overlays.addEntry('IntroBlock', (_, _) => const SizedBox.shrink());

        game.onGameResize(Vector2(390, 844));

        expect(
          game.board.introFillInProgress,
          isTrue,
          reason: '$mode should start with the board fill intro active',
        );
        expect(
          game.board.introFillPaused,
          isTrue,
          reason: '$mode should hold the intro while the loading overlay is up',
        );

        final timeBeforeLoadingRelease = game.timeRemaining;
        game.update(1);
        expect(
          game.board.introFillPaused,
          isTrue,
          reason: '$mode should not consume the intro while loading is visible',
        );
        expect(game.timeRemaining, timeBeforeLoadingRelease);

        game.releaseRoundStartIntro();
        expect(game.board.introFillPaused, isFalse);

        for (var frame = 0; frame < 180; frame++) {
          game.update(1 / 60);
          if (!game.board.introFillInProgress) break;
        }
        expect(
          game.board.introFillInProgress,
          isFalse,
          reason: '$mode should finish the visible intro after release',
        );

        final timeAfterIntro = game.timeRemaining;
        game.update(1);
        if (game.hasTimedClock) {
          expect(game.timeRemaining, lessThan(timeAfterIntro));
        } else {
          expect(game.timeRemaining, timeAfterIntro);
        }
      }
    },
  );

  test('manual board regeneration does not keep the fill intro paused', () async {
    SharedPreferences.setMockInitialValues({});
    await StorageHelper.init();
    await StorageHelper.erase();
    GameSettings.bgmMuted = true;
    GameSettings.sfxMuted = true;

    final game = MatchBoardGame(gameMode: JewelGameMode.simple);
    game.overlays.addEntry('IntroBlock', (_, _) => const SizedBox.shrink());
    game.onGameResize(Vector2(390, 844));
    game.releaseRoundStartIntro();

    for (var frame = 0; frame < 180; frame++) {
      game.update(1 / 60);
      if (!game.board.introFillInProgress) break;
    }
    expect(game.board.introFillInProgress, isFalse);

    game.newBoard();

    expect(game.board.introFillInProgress, isTrue);
    expect(game.board.introFillPaused, isFalse);
    for (var frame = 0; frame < 180; frame++) {
      game.update(1 / 60);
      if (!game.board.introFillInProgress) break;
    }
    expect(
      game.board.introFillInProgress,
      isFalse,
      reason:
          'manual regeneration should let the intro advance without a loading overlay',
    );
  });

  test('phase 1 targeted item selection keeps clock running', () {
    final game = MatchBoardGame(gameMode: JewelGameMode.timed);
    _setHintBoard(game.board);
    game.board.setGeometry(x: 0, y: 0, tile: 10);
    game.board.introFillInProgress = false;
    game.timeRemaining = 30;

    expect(game.startItemTargeting(ItemKind.runeHammer), isTrue);
    expect(game.isItemTargeting, isTrue);
    expect(game.itemFeedbackText, contains('제거할 보석 선택'));

    game.update(5);
    expect(game.timeRemaining, lessThan(30));
    final timeAfterTargeting = game.timeRemaining;

    final beforeA = game.board.getGem(0, 0);
    final beforeB = game.board.getGem(0, 1);
    game.handleBoardSwipe(5, 5, 5, 15, 0, 1);
    expect(game.board.getGem(0, 0), same(beforeA));
    expect(game.board.getGem(0, 1), same(beforeB));

    game.cancelItemTargeting();
    expect(game.isItemTargeting, isFalse);
    expect(game.itemFeedbackText, '아이템 선택 취소');
    game.update(5);
    expect(game.timeRemaining, lessThan(timeAfterTargeting));
  });

  test('stable-zone swipe works through MatchBoardGame input surface', () {
    final game = MatchBoardGame(gameMode: JewelGameMode.simple);
    _setStableZoneMatchBoard(game.board);
    game.board.setGeometry(x: 0, y: 0, tile: 10);
    game.board.introFillInProgress = false;
    game.board.state = 'falling';
    game.board.stageTimer = 12;

    final start = game.board.cellToPixel(6, 0);
    game.handleBoardSwipe(
      start.dx + 1,
      start.dy + 1,
      start.dx + 1,
      start.dy + 11,
      1,
      0,
    );

    expect(game.board.state, 'removing');
    expect(game.board.stageTimer, MatchBoardLogic.removeDelay);
    expect(game.board.pendingRemovalSet, containsPair('7:0', true));
    expect(game.board.pendingRemovalSet, containsPair('7:1', true));
    expect(game.board.pendingRemovalSet, containsPair('7:2', true));
  });

  test('stable-zone swipe blocks unsettled cells through game surface', () {
    final game = MatchBoardGame(gameMode: JewelGameMode.simple);
    _setStableZoneMatchBoard(game.board);
    game.board.setGeometry(x: 0, y: 0, tile: 10);
    game.board.introFillInProgress = false;
    game.board.state = 'falling';
    game.board.stageTimer = 12;
    final unstable = game.board.getGem(6, 0)!;
    unstable.y = unstable.targetY - game.board.tileSize;

    final start = game.board.cellToPixel(6, 0);
    game.handleBoardSwipe(
      start.dx + 1,
      start.dy + 1,
      start.dx + 1,
      start.dy + 11,
      1,
      0,
    );

    expect(game.board.state, 'falling');
    expect(game.board.stageTimer, 12);
    expect(game.board.pendingRemovalSet, isNull);
  });

  test('prism item requires explicit target color before board target', () {
    final game = MatchBoardGame(gameMode: JewelGameMode.timed);
    _setHintBoard(game.board);
    game.board.setGeometry(x: 0, y: 0, tile: 10);
    game.board.introFillInProgress = false;

    expect(game.startItemTargeting(ItemKind.prismTransform), isTrue);
    expect(game.isPrismColorPicking, isTrue);
    expect(game.itemFeedbackText, contains('바꿀 색 선택'));
    game.timeRemaining = 30;
    game.update(5);
    expect(game.timeRemaining, 30);

    final beforeColor = game.board.getGem(0, 0)!.color;
    game.handleBoardTap(5, 5);
    expect(game.isItemTargeting, isTrue);
    expect(game.board.getGem(0, 0)!.color, beforeColor);

    expect(game.selectPrismTargetColor(3), isTrue);
    expect(game.selectedPrismColor, 3);
    expect(game.itemFeedbackText, contains('바꿀 보석 선택'));
    game.update(5);
    expect(game.timeRemaining, lessThan(30));

    game.handleBoardTap(5, 5);
    expect(game.isItemTargeting, isFalse);
    expect(game.selectedPrismColor, isNull);
    expect(game.board.getGem(0, 0)?.color, 3);
    expect(game.itemFeedbackText, '보석 변환 완료');
  });

  test('phase 1 untargeted items respect mode restrictions', () {
    final simple = MatchBoardGame(gameMode: JewelGameMode.simple);
    final timed = MatchBoardGame(gameMode: JewelGameMode.timed);
    _setHintBoard(timed.board);
    timed.board.introFillInProgress = false;

    expect(simple.canUseTestItem(ItemKind.timeSlip), isFalse);
    expect(simple.canUseTestItem(ItemKind.hintPlus), isFalse);
    expect(timed.canUseTestItem(ItemKind.timeSlip), isTrue);
    expect(timed.canUseTestItem(ItemKind.hintPlus), isTrue);

    final beforeTime = timed.timeRemaining;
    expect(timed.useTestItem(ItemKind.timeSlip), isTrue);
    expect(timed.timeRemaining, greaterThanOrEqualTo(beforeTime));
    expect(timed.itemFeedbackText, contains('타임 슬립 +'));

    expect(timed.board.hintCellA, isNull);
    final beforeHints = timed.remainingHints;
    expect(timed.useTestItem(ItemKind.hintPlus), isTrue);
    expect(timed.remainingHints, beforeHints);
    expect(timed.board.hintCellA, isNotNull);
    expect(timed.board.hintCellB, isNotNull);
    expect(timed.itemFeedbackText, '힌트를 표시했습니다');
  });

  test('phase 1 untargeted hud items require confirmation', () {
    final timed = MatchBoardGame(gameMode: JewelGameMode.timed);
    _setHintBoard(timed.board);
    timed.board.introFillInProgress = false;

    final beforeTime = timed.timeRemaining;
    expect(timed.usePhaseOneItem(ItemKind.timeSlip), isTrue);
    expect(timed.pendingImmediateItemConfirm, ItemKind.timeSlip);
    expect(timed.timeRemaining, beforeTime);
    timed.update(5);
    expect(timed.timeRemaining, beforeTime);

    timed.cancelImmediateItemConfirm();
    expect(timed.pendingImmediateItemConfirm, isNull);
    expect(timed.timeRemaining, beforeTime);
    expect(timed.itemFeedbackText, '아이템 사용 취소');

    expect(timed.usePhaseOneItem(ItemKind.hintPlus), isTrue);
    expect(timed.pendingImmediateItemConfirm, ItemKind.hintPlus);
    final beforeHintConfirmTime = timed.timeRemaining;
    timed.update(5);
    expect(timed.timeRemaining, beforeHintConfirmTime);
    expect(timed.board.hintCellA, isNull);
    final beforeHints = timed.remainingHints;
    expect(timed.confirmImmediateItemUse(), isTrue);
    expect(timed.pendingImmediateItemConfirm, isNull);
    expect(timed.remainingHints, beforeHints);
    expect(timed.board.hintCellA, isNotNull);
    expect(timed.board.hintCellB, isNotNull);
    expect(timed.itemFeedbackText, '힌트를 표시했습니다');
  });

  test('phase 2 progression loadout is edited from next stage draft', () {
    final game = MatchBoardGame(gameMode: JewelGameMode.progression);

    expect(game.stageLoadout.slots, hasLength(4));
    expect(game.stageLoadout.slots[0].item, ItemKind.runeHammer);
    expect(game.stageLoadout.slots[1].item, ItemKind.ancientBomb);
    expect(game.stageLoadout.slots[2].locked, isTrue);
    expect(game.stageLoadout.slots[3].locked, isTrue);

    game.runInventory.add(ItemKind.thorHammer);
    expect(game.assignNextStageLoadoutSlot(1, ItemKind.thorHammer), isTrue);
    expect(game.nextStageLoadoutDraft.slots[1].item, ItemKind.thorHammer);
    expect(game.stageLoadout.slots[1].item, ItemKind.ancientBomb);

    game.levelUpToLevel = 2;
    game.overlays.addEntry('IntroBlock', (_, _) => const SizedBox.shrink());
    game.continueAfterLevelUp();

    expect(game.progressionLevel, 2);
    expect(game.stageLoadout.slots[1].item, ItemKind.thorHammer);
  });

  test(
    'phase 2 progression clear unlocks loadout slots with inventory popup',
    () async {
      SharedPreferences.setMockInitialValues({});
      await StorageHelper.init();
      await StorageHelper.erase();
      GameSettings.sfxMuted = true;
      final game = MatchBoardGame(gameMode: JewelGameMode.progression);
      game.overlays.addEntry('IntroBlock', (_, _) => const SizedBox());
      game.overlays.addEntry('LevelCelebration', (_, _) => const SizedBox());
      game.overlays.addEntry('LevelUp', (_, _) => const SizedBox());
      game.overlays.addEntry('StageInventory', (_, _) => const SizedBox());

      expect(game.stageLoadoutOpenSlotCount, 2);

      _clearProgressionStage(game, level: 6);

      expect(game.levelUpFromLevel, 6);
      expect(game.stageLoadoutOpenSlotCount, 3);
      expect(game.recentlyUnlockedLoadoutSlotIndices, [2]);
      expect(game.nextStageLoadoutDraft.slots[2].locked, isFalse);
      expect(game.nextStageLoadoutDraft.slots[2].item, isNull);
      expect(game.overlays.isActive('LevelCelebration'), isTrue);

      game.showLevelUpPopupAfterCelebration();

      expect(game.overlays.isActive('LevelUp'), isTrue);
      expect(game.overlays.isActive('StageInventory'), isTrue);

      game.continueAfterLevelUp();
      expect(game.stageLoadout.openSlotCount, 3);
      expect(game.recentlyUnlockedLoadoutSlotIndices, isEmpty);

      _primeMultiRewardStats(game);
      _clearProgressionStage(game, level: 12);

      expect(game.stageLoadoutOpenSlotCount, 4);
      expect(game.recentlyUnlockedLoadoutSlotIndices, [3]);

      game.showLevelUpPopupAfterCelebration();

      expect(game.overlays.isActive('StageInventory'), isTrue);
    },
  );

  test(
    'phase 2 progression item use consumes temporary inventory on success',
    () {
      final game = MatchBoardGame(gameMode: JewelGameMode.progression);
      _setHintBoard(game.board);
      game.board.setGeometry(x: 0, y: 0, tile: 10);
      game.board.introFillInProgress = false;

      expect(game.runInventory.quantityOf(ItemKind.runeHammer), 1);
      expect(game.usePhaseOneItem(ItemKind.runeHammer), isTrue);
      expect(game.isItemTargeting, isTrue);

      game.handleBoardTap(5, 5);

      expect(game.isItemTargeting, isFalse);
      expect(game.runInventory.quantityOf(ItemKind.runeHammer), 0);
      expect(game.usePhaseOneItem(ItemKind.runeHammer), isFalse);
    },
  );
}

void _clearProgressionStage(MatchBoardGame game, {required int level}) {
  game.progressionLevel = level;
  game.board.score = game.progressionTargetScore;
  game.board.introFillInProgress = false;
  game.isPlaying = true;
  game.update(0);
}

void _primeMultiRewardStats(MatchBoardGame game) {
  game.board.maxCombo = 5;
  game.board.stats.recordValidSwap();
  game.board.stats.recordMatchGroups(24);
  game.board.stats.recordSpecialCreated(GemKind.bomb);
  game.board.stats.recordSpecialCreated(GemKind.star);
  game.board.stats.recordSpecialCreated(GemKind.hyper);
  for (var i = 0; i < 100; i++) {
    game.board.stats.recordGemRemoved(GemKind.normal);
  }
}

void _setHintBoard(MatchBoardLogic board) {
  _setRows(board, _validMoveRows);
}

const _validMoveRows = [
  [1, 2, 1, 4, 5, 6, 1, 2],
  [2, 1, 4, 5, 6, 1, 2, 3],
  [3, 4, 3, 6, 1, 2, 3, 4],
  [4, 3, 6, 1, 2, 3, 4, 5],
  [5, 6, 1, 2, 3, 4, 5, 6],
  [6, 1, 2, 3, 4, 5, 6, 1],
  [1, 2, 3, 4, 5, 6, 1, 2],
  [2, 3, 4, 5, 6, 1, 2, 3],
];

void _setRows(MatchBoardLogic board, List<List<int>> rows) {
  for (var row = 0; row < rows.length; row++) {
    for (var col = 0; col < rows[row].length; col++) {
      final token = rows[row][col];
      final kind = switch (token) {
        -1 => GemKind.bomb,
        -2 => GemKind.star,
        _ => GemKind.normal,
      };
      final color = token < 0 ? token.abs() : token;
      board.setGem(row, col, board.createGem(row, col, color, kind));
    }
  }
}

void _setStableZoneMatchBoard(MatchBoardLogic board) {
  for (var row = 0; row < MatchBoardGame.rows; row++) {
    for (var col = 0; col < MatchBoardGame.cols; col++) {
      final color = (row + col) % 6 + 1;
      board.setGem(row, col, board.createGem(row, col, color, GemKind.normal));
    }
  }
  board.setGem(6, 0, board.createGem(6, 0, 2, GemKind.normal));
  board.setGem(7, 0, board.createGem(7, 0, 5, GemKind.normal));
  board.setGem(7, 1, board.createGem(7, 1, 2, GemKind.normal));
  board.setGem(7, 2, board.createGem(7, 2, 2, GemKind.normal));
  board.setGem(7, 3, board.createGem(7, 3, 4, GemKind.normal));
}

String _hintKey(MatchBoardLogic board) {
  final a = board.hintCellA;
  final b = board.hintCellB;
  expect(a, isNotNull);
  expect(b, isNotNull);
  return '${a!.x}:${a.y}>${b!.x}:${b.y}';
}

Set<String> _moveKeys(List<ValidMovePair> moves) {
  return {
    for (final move in moves) '${move.a.x}:${move.a.y}>${move.b.x}:${move.b.y}',
  };
}
