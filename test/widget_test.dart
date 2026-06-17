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
      _setRows(game.board, const [
        [5, 1, 3, 3, 5, 1, 1, 6],
        [6, 5, 4, 6, 2, 1, 4, 5],
        [4, 3, 1, 6, 5, 5, 3, 2],
        [5, -2, 2, 2, 4, 6, 2, 4],
        [3, 4, 6, 4, 5, 1, 5, 1],
        [2, -1, 1, 5, 2, 4, -1, 6],
        [4, 5, 1, 1, 2, 6, 3, 3],
        [1, 4, 6, 6, 3, 4, 1, 1],
      ]);
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
    game.handleBoardSwipe(5, 5, 0, 1);
    expect(game.board.getGem(0, 0), same(beforeA));
    expect(game.board.getGem(0, 1), same(beforeB));

    game.cancelItemTargeting();
    expect(game.isItemTargeting, isFalse);
    expect(game.itemFeedbackText, '아이템 선택 취소');
    game.update(5);
    expect(game.timeRemaining, lessThan(timeAfterTargeting));
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

    expect(simple.canUseTestItem(ItemKind.timeSlip), isFalse);
    expect(simple.canUseTestItem(ItemKind.hintPlus), isFalse);
    expect(timed.canUseTestItem(ItemKind.timeSlip), isTrue);
    expect(timed.canUseTestItem(ItemKind.hintPlus), isTrue);

    final beforeTime = timed.timeRemaining;
    expect(timed.useTestItem(ItemKind.timeSlip), isTrue);
    expect(timed.timeRemaining, greaterThanOrEqualTo(beforeTime));
    expect(timed.itemFeedbackText, contains('타임 슬립 +'));

    final beforeHints = timed.remainingHints;
    expect(timed.useTestItem(ItemKind.hintPlus), isTrue);
    expect(timed.remainingHints, beforeHints + 1);
    expect(timed.itemFeedbackText, '힌트 +1');
  });

  test('phase 1 untargeted hud items require confirmation', () {
    final timed = MatchBoardGame(gameMode: JewelGameMode.timed);

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
    final beforeHints = timed.remainingHints;
    expect(timed.confirmImmediateItemUse(), isTrue);
    expect(timed.pendingImmediateItemConfirm, isNull);
    expect(timed.remainingHints, beforeHints + 1);
    expect(timed.itemFeedbackText, '힌트 +1');
  });
}

void _setHintBoard(MatchBoardLogic board) {
  _setRows(board, const [
    [5, 1, 3, 3, 5, 1, 1, 6],
    [6, 5, 4, 6, 2, 1, 4, 5],
    [4, 3, 1, 6, 5, 5, 3, 2],
    [5, -2, 2, 2, 4, 6, 2, 4],
    [3, 4, 6, 4, 5, 1, 5, 1],
    [2, -1, 1, 5, 2, 4, -1, 6],
    [4, 5, 1, 1, 2, 6, 3, 3],
    [1, 4, 6, 6, 3, 4, 1, 1],
  ]);
}

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
