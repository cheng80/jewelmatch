import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
