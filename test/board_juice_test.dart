import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/game/match_board_logic.dart';
import 'package:stonematch/game/match_board_game.dart';
import 'package:stonematch/game/components/board_juice_layer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('juice atlas renders again after removal and remount', () async {
    final game = MatchBoardGame();
    final layer = BoardJuiceLayer()..game = game;
    Future<bool> hasVisiblePixels() async {
      layer.onRemovalStarted({'0:0': true});
      layer.update(0.02);
      final recorder = ui.PictureRecorder();
      layer.render(ui.Canvas(recorder));
      final picture = recorder.endRecording();
      final image = await picture.toImage(128, 128);
      final bytes = await image.toByteData();
      var visible = false;
      for (var i = 3; i < bytes!.lengthInBytes; i += 4) {
        if (bytes.getUint8(i) > 0) {
          visible = true;
          break;
        }
      }
      image.dispose();
      picture.dispose();
      return visible;
    }

    layer.onMount();
    expect(await hasVisiblePixels(), isTrue);
    layer.onRemove();
    layer.onMount();
    expect(await hasVisiblePixels(), isTrue);
    layer.onRemove();
  });

  test('idle twinkles never hold level completion but a burst does', () {
    final game = MatchBoardGame();
    final layer = BoardJuiceLayer()..game = game;
    game.board.generateFreshBoard();
    game.board.introFillInProgress = false;
    for (var i = 0; i < 100; i++) {
      layer.update(0.02);
    }
    expect(layer.busy, isFalse);
    layer.onGemsRemoved(
      [(row: 2, col: 2, color: 1)],
      bigMatch: false,
      hasSpecial: false,
      combo: 1,
      gained: 100,
    );
    expect(layer.busy, isTrue);
    layer.update(0.7);
    expect(layer.busy, isTrue);
    layer.update(0.2);
    expect(layer.busy, isFalse);
  });

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

  test(
    'a 4 match pulls removed gems into the spawn cell and pops the bomb',
    () {
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
    },
  );

  test('invalid swap bumps both gems without moving their targets', () {
    final board = MatchBoardLogic(rows: 8, cols: 8);
    final a = board.createGem(0, 0, 1, GemKind.normal);
    final b = board.createGem(0, 1, 2, GemKind.normal);
    board
      ..setGem(0, 0, a)
      ..setGem(0, 1, b);

    expect(board.trySwap(0, 0, 0, 1), isFalse);

    board.update(0.09);
    expect(board.inputLocked, isFalse);
    expect(a.x, greaterThan(a.targetX));
    expect(b.x, lessThan(b.targetX));
    expect(board.getGem(0, 0), same(a));
    board.update(0.1);
    expect(a.x, a.targetX);
    expect(b.x, b.targetX);
    expect(a.bumpT, -1);
  });
}
