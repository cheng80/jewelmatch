import 'package:flutter_test/flutter_test.dart';
import 'package:jewelmatch/game/match_board_logic.dart';

void main() {
  test('special gems emit distinct effect descriptors with shake tuning', () {
    final bomb = _activateSingleSpecial(GemKind.bomb, row: 3, col: 3).single;
    final star = _activateSingleSpecial(GemKind.star, row: 3, col: 3).single;
    final hyper = _activateSingleSpecial(GemKind.hyper, row: 3, col: 3).single;
    final supernova = _activateSingleSpecial(
      GemKind.supernova,
      row: 3,
      col: 3,
    ).single;

    final events = [bomb, star, hyper, supernova];

    expect(
      events.map((event) => event.effectKind).toSet(),
      equals({GemKind.bomb, GemKind.star, GemKind.hyper, GemKind.supernova}),
    );
    expect(
      events.map((event) => event.shake.intensity).toSet(),
      hasLength(events.length),
    );
    expect(
      events.map((event) => event.shake.duration).toSet(),
      hasLength(events.length),
    );

    for (final event in events) {
      expect(event.shake.intensity, greaterThan(0));
      expect(event.shake.duration, greaterThan(0));
    }
  });

  test('supernova descriptor at top-left only contains in-bounds cells', () {
    final event = _activateSingleSpecial(
      GemKind.supernova,
      row: 0,
      col: 0,
    ).single;

    expect(event.effectKind, GemKind.supernova);
    for (final point in event.affectedCells) {
      expect(point.x, inInclusiveRange(0, 7));
      expect(point.y, inInclusiveRange(0, 7));
    }
  });
}

List<SpecialEffectEvent> _activateSingleSpecial(
  GemKind kind, {
  required int row,
  required int col,
}) {
  final board = _filledBoard();
  board.setGem(row, col, board.createGem(row, col, 2, kind));

  final removalSet = {'$row:$col': true};
  final queue = board.buildSpecialQueue(removalSet);

  board.activateSpecials(removalSet, queue);

  return board.consumeSpecialEffectEvents();
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
