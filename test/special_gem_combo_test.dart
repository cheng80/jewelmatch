import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/game/match_board_logic.dart';

void main() {
  test('bomb plus bomb clears a larger 5 by 5 blast', () {
    final board = _filledBoard();
    board.setGem(3, 3, board.createGem(3, 3, 2, GemKind.bomb));
    board.setGem(3, 4, board.createGem(3, 4, 4, GemKind.bomb));

    final swapped = board.trySwap(3, 3, 3, 4);

    expect(swapped, isTrue);
    for (var row = 1; row <= 5; row++) {
      for (var col = 1; col <= 5; col++) {
        expect(board.pendingRemovalSet, containsPair('$row:$col', true));
      }
    }
    expect(board.consumeSpecialEffectEvents(), hasLength(2));
  });

  test('bomb plus star blasts along the star row and column', () {
    final board = _filledBoard();
    board.setGem(3, 3, board.createGem(3, 3, 2, GemKind.bomb));
    board.setGem(3, 4, board.createGem(3, 4, 4, GemKind.star));

    final swapped = board.trySwap(3, 3, 3, 4);

    expect(swapped, isTrue);
    for (var col = 0; col < 8; col++) {
      expect(board.pendingRemovalSet, containsPair('3:$col', true));
    }
    for (var row = 0; row < 8; row++) {
      expect(board.pendingRemovalSet, containsPair('$row:4', true));
    }
    expect(board.pendingRemovalSet, containsPair('2:0', true));
    expect(board.pendingRemovalSet, containsPair('4:7', true));
    expect(board.consumeSpecialEffectEvents(), hasLength(2));
  });

  test('adjacent star plus star triggers when swapped orthogonally', () {
    final board = _filledBoard();
    board.setGem(3, 3, board.createGem(3, 3, 2, GemKind.star));
    board.setGem(3, 4, board.createGem(3, 4, 4, GemKind.star));

    final swapped = board.trySwap(3, 3, 3, 4);

    expect(swapped, isTrue);
    for (var col = 0; col < 8; col++) {
      expect(board.pendingRemovalSet, containsPair('3:$col', true));
    }
    for (var row = 0; row < 8; row++) {
      expect(board.pendingRemovalSet, containsPair('$row:3', true));
      expect(board.pendingRemovalSet, containsPair('$row:4', true));
    }
    expect(board.consumeSpecialEffectEvents(), hasLength(2));
    expect(board.stats.validSwaps, 1);
    expect(board.stats.specialGemsActivated, 2);
    expect(board.stats.specialActivatedByKind[GemKind.star], 2);

    final removalCount = board.pendingRemovalSet!.length;
    board.removeMarkedGems(board.pendingRemovalSet!);

    expect(board.stats.removedGems, removalCount);
    expect(board.stats.removedByKind[GemKind.star], 2);
    expect(board.stats.removedSpecialGems, 2);
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
