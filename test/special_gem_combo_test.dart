import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/game/match_board_logic.dart';

void main() {
  test('adjacent non-hyper special gems do not activate by swapping', () {
    final board = _filledBoard();
    board.setGem(3, 3, board.createGem(3, 3, 2, GemKind.bomb));
    board.setGem(3, 4, board.createGem(3, 4, 4, GemKind.star));

    final swapped = board.trySwap(3, 3, 3, 4);

    expect(swapped, isFalse);
    expect(board.pendingRemovalSet, isNull);
    expect(board.consumeSpecialEffectEvents(), isEmpty);
    expect(board.stats.specialGemsActivated, 0);
  });

  test('tapped bomb chains into a star in its blast area', () {
    final board = _filledBoard();
    board.setGem(3, 3, board.createGem(3, 3, 2, GemKind.bomb));
    board.setGem(3, 4, board.createGem(3, 4, 4, GemKind.star));

    final activated = board.triggerSpecialCell(3, 3);

    expect(activated, isTrue);
    for (var row = 2; row <= 4; row++) {
      for (var col = 2; col <= 4; col++) {
        expect(board.pendingRemovalSet, containsPair('$row:$col', true));
      }
    }
    for (var col = 0; col < 8; col++) {
      expect(board.pendingRemovalSet, containsPair('3:$col', true));
    }
    for (var row = 0; row < 8; row++) {
      expect(board.pendingRemovalSet, containsPair('$row:4', true));
    }
    expect(board.stats.specialActivatedByKind[GemKind.bomb], 1);
    expect(board.stats.specialActivatedByKind[GemKind.star], 1);
    expect(
      board.consumeSpecialEffectEvents().map((event) => event.effectKind),
      [GemKind.bomb, GemKind.star],
    );
  });

  test('hyper inside another special range is removed without chaining', () {
    final board = _filledBoard();
    board.setGem(3, 3, board.createGem(3, 3, 2, GemKind.bomb));
    board.setGem(3, 4, board.createGem(3, 4, 0, GemKind.hyper));

    final activated = board.triggerSpecialCell(3, 3);

    expect(activated, isTrue);
    expect(board.pendingRemovalSet, containsPair('3:4', true));
    expect(board.stats.specialActivatedByKind[GemKind.bomb], 1);
    expect(board.stats.specialActivatedByKind[GemKind.hyper] ?? 0, 0);
    expect(board.consumeSpecialEffectEvents(), hasLength(1));
  });
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
