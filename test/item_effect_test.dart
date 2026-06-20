import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/game/item_kind.dart';
import 'package:stonematch/game/match_board_logic.dart';

void main() {
  test('phase 1 item effects mark safe board ranges from a corner', () {
    final board = _filledBoard();

    expect(board.useBoardItem(ItemKind.runeHammer, row: 0, col: 0), isTrue);
    expect(board.pendingRemovalSet, containsPair('0:0', true));
    expect(board.pendingRemovalSet, hasLength(1));

    board.finishResolutionFlow();
    expect(board.useBoardItem(ItemKind.ancientBomb, row: 0, col: 0), isTrue);
    final ancientBombEffects = board.consumeSpecialEffectEvents();
    expect(ancientBombEffects, hasLength(1));
    expect(ancientBombEffects.single.effectKind, GemKind.bomb);
    expect(ancientBombEffects.single.origin.x, 0);
    expect(ancientBombEffects.single.origin.y, 0);
    expect(board.pendingRemovalSet, containsPair('0:0', true));
    expect(board.pendingRemovalSet, containsPair('0:1', true));
    expect(board.pendingRemovalSet, containsPair('1:0', true));
    expect(board.pendingRemovalSet, containsPair('1:1', true));
    expect(board.pendingRemovalSet, hasLength(4));

    board.finishResolutionFlow();
    expect(board.useBoardItem(ItemKind.thorHammer, row: 0, col: 0), isTrue);
    expect(
      board.pendingRemovalSet!.keys.where((key) => key.startsWith('0:')),
      hasLength(8),
    );
    expect(
      board.pendingRemovalSet!.keys.where((key) => key.endsWith(':0')),
      hasLength(8),
    );
  });

  test(
    'hyper cube removes same-color non-hyper gems using selected gem color',
    () {
      final board = _filledBoard();
      board.setGem(0, 0, board.createGem(0, 0, 2, GemKind.star));
      board.setGem(0, 1, board.createGem(0, 1, 2, GemKind.hyper));
      board.setGem(1, 0, board.createGem(1, 0, 2, GemKind.normal));
      board.setGem(1, 1, board.createGem(1, 1, 3, GemKind.normal));

      expect(board.useBoardItem(ItemKind.hyperCube, row: 0, col: 0), isTrue);

      expect(board.pendingRemovalSet, containsPair('0:0', true));
      expect(board.pendingRemovalSet, containsPair('1:0', true));
      expect(board.pendingRemovalSet, isNot(containsPair('0:1', true)));
      expect(board.pendingRemovalSet, isNot(containsPair('1:1', true)));
    },
  );

  test('prism transform changes color and starts match resolution', () {
    final board = MatchBoardLogic(rows: 8, cols: 8);
    _setRows(board, const [
      [1, 1, 2, 3, 4, 5, 6, 1],
      [2, 3, 4, 5, 6, 1, 2, 3],
      [3, 4, 5, 6, 1, 2, 3, 4],
      [4, 5, 6, 1, 2, 3, 4, 5],
      [5, 6, 1, 2, 3, 4, 5, 6],
      [6, 1, 2, 3, 4, 5, 6, 1],
      [1, 2, 3, 4, 5, 6, 1, 2],
      [2, 3, 4, 5, 6, 1, 2, 3],
    ]);

    expect(
      board.useBoardItem(
        ItemKind.prismTransform,
        row: 0,
        col: 2,
        prismColor: 1,
      ),
      isTrue,
    );

    expect(board.getGem(0, 2)?.color, 1);
    expect(board.state, 'removing');
    expect(board.pendingRemovalSet, containsPair('0:0', true));
    expect(board.pendingRemovalSet, containsPair('0:1', true));
    expect(board.pendingRemovalSet, containsPair('0:2', true));
  });

  test(
    'fate shuffle preserves special coordinates and leaves a valid move',
    () {
      final board = _filledBoard();
      board.setGem(2, 3, board.createGem(2, 3, 4, GemKind.star));
      board.setGem(5, 5, board.createGem(5, 5, 1, GemKind.bomb));

      expect(board.useUntargetedBoardItem(ItemKind.fateShuffle), isTrue);

      expect(board.getGem(2, 3)?.kind, GemKind.star);
      expect(board.getGem(5, 5)?.kind, GemKind.bomb);
      expect(board.hasAnyValidMove(), isTrue);
    },
  );
}

MatchBoardLogic _filledBoard() {
  final board = MatchBoardLogic(rows: 8, cols: 8);
  for (var row = 0; row < 8; row++) {
    for (var col = 0; col < 8; col++) {
      final color = (row + col) % 6 + 1;
      board.setGem(row, col, board.createGem(row, col, color, GemKind.normal));
    }
  }
  return board;
}

void _setRows(MatchBoardLogic board, List<List<int>> rows) {
  for (var row = 0; row < rows.length; row++) {
    for (var col = 0; col < rows[row].length; col++) {
      final color = rows[row][col];
      board.setGem(row, col, board.createGem(row, col, color, GemKind.normal));
    }
  }
}
