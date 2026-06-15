import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:jewelmatch/game/match_board_logic.dart';

void main() {
  test('4 in a row creates a flame gem', () {
    final board = _boardWithLine(length: 4);
    final matches = board.findAllMatches();

    final spawns = board.classifyMatchGroups(matches, const Point(0, 1), null);

    expect(spawns, hasLength(1));
    expect(spawns.single.kind, GemKind.bomb);
    expect(spawns.single.row, 0);
    expect(spawns.single.col, 1);
  });

  test('T or L shape creates a star gem only', () {
    final board = MatchBoardLogic(rows: 8, cols: 8);
    for (final cell in const [
      Point(3, 2),
      Point(3, 3),
      Point(3, 4),
      Point(2, 3),
      Point(4, 3),
    ]) {
      board.setGem(
        cell.x,
        cell.y,
        board.createGem(cell.x, cell.y, 2, GemKind.normal),
      );
    }

    final matches = board.findAllMatches();
    final spawns = board.classifyMatchGroups(matches, const Point(3, 3), null);

    expect(spawns, hasLength(1));
    expect(spawns.single.kind, GemKind.star);
    expect(spawns.single.row, 3);
    expect(spawns.single.col, 3);
  });

  test('5 in a row creates a hyper gem', () {
    final board = _boardWithLine(length: 5);
    final matches = board.findAllMatches();

    final spawns = board.classifyMatchGroups(matches, const Point(0, 2), null);

    expect(spawns, hasLength(1));
    expect(spawns.single.kind, GemKind.hyper);
    expect(spawns.single.color, 0);
  });

  test('6 or more in a row creates a supernova gem', () {
    final board = _boardWithLine(length: 6);
    final matches = board.findAllMatches();

    final spawns = board.classifyMatchGroups(matches, const Point(0, 3), null);

    expect(spawns, hasLength(1));
    expect(spawns.single.kind, GemKind.supernova);
    expect(spawns.single.color, 1);
  });

  test('star gem clears its row and column', () {
    final board = _filledBoard();
    board.setGem(3, 4, board.createGem(3, 4, 2, GemKind.star));
    final removalSet = {'3:4': true};
    final queue = board.buildSpecialQueue(removalSet);

    board.activateSpecials(removalSet, queue);

    expect(removalSet.keys.where((key) => key.startsWith('3:')), hasLength(8));
    expect(removalSet.keys.where((key) => key.endsWith(':4')), hasLength(8));
    expect(removalSet, containsPair('0:4', true));
    expect(removalSet, containsPair('3:7', true));
  });

  test('special gem activation adds bonus score', () {
    final board = _filledBoard();
    board.setGem(3, 3, board.createGem(3, 3, 2, GemKind.bomb));
    final removalSet = {'3:3': true};
    final queue = board.buildSpecialQueue(removalSet);
    board.activateSpecials(removalSet, queue);

    board.removeMarkedGems(removalSet);

    expect(board.score, 900);
  });

  test('supernova gem combines 3x3 blast with row and column clear', () {
    final board = _filledBoard();
    board.setGem(3, 4, board.createGem(3, 4, 5, GemKind.supernova));
    final removalSet = {'3:4': true};
    final queue = board.buildSpecialQueue(removalSet);

    board.activateSpecials(removalSet, queue);

    expect(removalSet.keys.where((key) => key.startsWith('3:')), hasLength(8));
    expect(removalSet.keys.where((key) => key.endsWith(':4')), hasLength(8));
    for (var row = 2; row <= 4; row++) {
      for (var col = 3; col <= 5; col++) {
        expect(removalSet, containsPair('$row:$col', true));
      }
    }
  });

  test('non-hyper special gem does not trigger by swapping with any gem', () {
    final board = _filledBoard();
    board.setGem(3, 3, board.createGem(3, 3, 2, GemKind.bomb));
    board.setGem(3, 4, board.createGem(3, 4, 5, GemKind.normal));

    final swapped = board.trySwap(3, 3, 3, 4);

    expect(swapped, isFalse);
    expect(board.getGem(3, 3)?.kind, GemKind.bomb);
    expect(board.getGem(3, 4)?.kind, GemKind.normal);
    expect(board.consumeSpecialEffectEvents(), isEmpty);
  });

  test('non-hyper special gem matches same-color normal gems', () {
    final board = _filledBoard();
    board.setGem(3, 1, board.createGem(3, 1, 2, GemKind.normal));
    board.setGem(3, 2, board.createGem(3, 2, 3, GemKind.normal));
    board.setGem(3, 3, board.createGem(3, 3, 2, GemKind.normal));
    board.setGem(3, 4, board.createGem(3, 4, 5, GemKind.normal));
    board.setGem(4, 2, board.createGem(4, 2, 2, GemKind.star));

    final swapped = board.trySwap(3, 2, 4, 2);

    expect(swapped, isTrue);
    expect(
      board.consumeSpecialEffectEvents().map((event) => event.effectKind),
      contains(GemKind.star),
    );
  });

  test('non-hyper special gems do not match by kind across colors', () {
    final board = _filledBoard();
    board.setGem(4, 0, board.createGem(4, 0, 6, GemKind.normal));
    board.setGem(4, 1, board.createGem(4, 1, 1, GemKind.bomb));
    board.setGem(4, 2, board.createGem(4, 2, 2, GemKind.bomb));
    board.setGem(5, 0, board.createGem(5, 0, 3, GemKind.bomb));

    final swapped = board.trySwap(4, 0, 5, 0);

    expect(swapped, isFalse);
    expect(board.consumeSpecialEffectEvents(), isEmpty);
  });

  test('hyper gem still triggers by swapping with a normal gem', () {
    final board = _filledBoard();
    board.setGem(3, 3, board.createGem(3, 3, 0, GemKind.hyper));
    board.setGem(3, 4, board.createGem(3, 4, 5, GemKind.normal));

    final swapped = board.trySwap(3, 3, 3, 4);

    expect(swapped, isTrue);
    expect(board.consumeSpecialEffectEvents().single.effectKind, GemKind.hyper);
  });

  test(
    'hint candidates exclude adjacent non-hyper specials without a match',
    () {
      final board = _filledBoard();
      board.setGem(3, 3, board.createGem(3, 3, 2, GemKind.bomb));
      board.setGem(3, 4, board.createGem(3, 4, 5, GemKind.star));

      final moves = board.getAllValidMoves();

      expect(
        moves,
        isNot(
          contains(
            predicate<ValidMovePair>(
              (move) =>
                  move.a == const Point(3, 3) && move.b == const Point(3, 4),
            ),
          ),
        ),
      );
    },
  );

  test('screenshot board has valid moves under color match rules', () {
    final board = MatchBoardLogic(rows: 8, cols: 8);
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

    final moves = board.getAllValidMoves();

    expect(moves, isNotEmpty);
    expect(board.showHint(), isTrue);
  });

  test('showHint chooses cells that produce a valid swap', () {
    final board = MatchBoardLogic(rows: 8, cols: 8);
    board.generateFreshBoard(withIntroFill: false);

    final shown = board.showHint();

    final a = board.hintCellA;
    final b = board.hintCellB;
    expect(shown, isTrue);
    expect(a, isNotNull);
    expect(b, isNotNull);
    expect(board.areAdjacent(a!.x, a.y, b!.x, b.y), isTrue);
    expect(board.trySwap(a.x, a.y, b.x, b.y), isTrue);
  });
}

MatchBoardLogic _boardWithLine({required int length}) {
  final board = MatchBoardLogic(rows: 8, cols: 8);
  for (var col = 0; col < length; col++) {
    board.setGem(0, col, board.createGem(0, col, 1, GemKind.normal));
  }
  return board;
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
