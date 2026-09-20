import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/game/match_board_logic.dart';

void main() {
  test('falling gem starts a landing squash, then the timer expires', () {
    final board = MatchBoardLogic(rows: 8, cols: 8);
    final gem = board.createGem(5, 0, 1, GemKind.normal, spawnOffsetRows: 3);
    board.setGem(5, 0, gem);

    board.update(1 / 60);
    expect(gem.airborne, isTrue);
    expect(gem.landT, lessThan(0));

    var squashed = false;
    for (var i = 0; i < 120; i++) {
      board.update(1 / 60);
      squashed = squashed || gem.landT >= 0;
    }
    expect(squashed, isTrue);
    expect(gem.airborne, isFalse);
    expect(gem.landT, lessThan(0));
  });

  test('a 4 match pulls removed gems into the spawn cell and pops the bomb', () {
    final board = MatchBoardLogic(rows: 8, cols: 8);
    for (var col = 0; col < 4; col++) {
      board.setGem(0, col, board.createGem(0, col, 1, GemKind.normal));
    }

    board.resolveMatchCascade(
      MoveInfo(movedA: const Point(0, 1), movedB: const Point(0, 1)),
    );

    final bomb = board.getGem(0, 1)!;
    expect(bomb.kind, GemKind.bomb);
    expect(bomb.popT, 0);
    expect(bomb.targetX, board.cellToPixel(0, 1).dx);
    for (final col in [0, 2, 3]) {
      expect(board.getGem(0, col)!.targetX, bomb.targetX);
    }
  });

  test('invalid swap bumps both gems without moving their targets', () {
    final board = MatchBoardLogic(rows: 8, cols: 8);
    final a = board.createGem(0, 0, 1, GemKind.normal);
    final b = board.createGem(0, 1, 2, GemKind.normal);
    board
      ..setGem(0, 0, a)
      ..setGem(0, 1, b);

    expect(board.trySwap(0, 0, 0, 1), isFalse);

    expect(a.x, greaterThan(a.targetX));
    expect(b.x, lessThan(b.targetX));
    expect(board.getGem(0, 0), same(a));
  });
}
