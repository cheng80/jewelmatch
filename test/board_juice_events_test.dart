import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/game/components/board_juice_layer.dart';
import 'package:stonematch/game/match_board_game.dart';
import 'package:stonematch/game/match_board_logic.dart';
import 'package:stonematch/game/jewel_game_mode.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final length in [3, 4, 5, 6, 7]) {
    test(
      '$length match reports original shape, birth once and unchanged score',
      () {
        final board = MatchBoardLogic(rows: 8, cols: 8);
        final births = <SpecialSpawn>[];
        board.onSpecialsBorn = births.addAll;
        for (var col = 0; col < length; col++) {
          board.setGem(3, col, board.createGem(3, col, 2, GemKind.normal));
        }
        board.resolveMatchCascade(
          MoveInfo(movedA: const Point(3, 1), movedB: const Point(3, 1)),
        );
        expect(
          board.removalJuicePattern,
          length == 3
              ? MatchJuicePattern.normal
              : length == 4
              ? MatchJuicePattern.four
              : length == 5
              ? MatchJuicePattern.five
              : MatchJuicePattern.sixPlus,
        );
        expect(births.length, length == 3 ? 0 : 1);
        if (births.isNotEmpty) {
          expect(
            births.single.kind,
            length == 4
                ? GemKind.bomb
                : length == 5
                ? GemKind.hyper
                : GemKind.supernova,
          );
        }
        final removed = length - (length == 3 ? 0 : 1);
        board.advanceResolutionStep();
        expect(board.score, 100 + max(0, removed - 3) * 50);
        expect(board.lastRemovalScore, board.score);
        expect(births.length, length == 3 ? 0 : 1);
      },
    );
  }

  for (final shape in ['T', 'L']) {
    test(
      '$shape intersection reports cross and star without score changes',
      () {
        final board = MatchBoardLogic(rows: 8, cols: 8);
        final births = <SpecialSpawn>[];
        board.onSpecialsBorn = births.addAll;
        final cells = shape == 'T'
            ? [
                const Point(2, 2),
                const Point(2, 3),
                const Point(2, 4),
                const Point(3, 3),
                const Point(4, 3),
              ]
            : [
                const Point(2, 2),
                const Point(2, 3),
                const Point(2, 4),
                const Point(3, 2),
                const Point(4, 2),
              ];
        for (final cell in cells) {
          board.setGem(
            cell.x,
            cell.y,
            board.createGem(cell.x, cell.y, 1, GemKind.normal),
          );
        }
        board.resolveMatchCascade(
          MoveInfo(movedA: cells.first, movedB: cells.first),
        );
        expect(board.removalJuicePattern, MatchJuicePattern.cross);
        expect(births.single.kind, GemKind.star);
        board.advanceResolutionStep();
        expect(board.score, 150);
      },
    );
  }

  test('tap chain resets stale match shape and retains hyper exclusion', () {
    final game = MatchBoardGame();
    final board = game.board;
    board.removalJuicePattern = MatchJuicePattern.sixPlus;
    for (var col = 2; col < 5; col++) {
      final kind = col == 2
          ? GemKind.bomb
          : col == 3
          ? GemKind.star
          : GemKind.hyper;
      board.setGem(3, col, board.createGem(3, col, 2, kind));
    }
    expect(board.triggerSpecialCell(3, 2), isTrue);
    final events = board.consumeSpecialEffectEvents();
    expect(events.map((e) => e.effectKind), [GemKind.bomb, GemKind.star]);
    expect(board.removalJuicePattern, MatchJuicePattern.normal);
    final layer = BoardJuiceLayer()..game = game;
    layer.onSpecialsActivated(events);
    expect(layer.busy, isTrue);
    expect(layer.liveSparkCount, greaterThan(10));
    layer.update(0.81);
    expect(layer.busy, isFalse);
    layer.onRemove();
  });

  test('refill and landing emit once each and never hold completion', () {
    final game = MatchBoardGame();
    final board = game.board;
    final layer = BoardJuiceLayer()..game = game;
    final gem = board.createGem(4, 2, 3, GemKind.normal, spawnOffsetRows: 3);
    gem.juiceRefillPending = true;
    board.setGem(4, 2, gem);
    layer.update(0.01);
    expect(layer.liveSparkCount, 1);
    expect(gem.juiceRefillPending, isFalse);
    expect(gem.juiceFalling, isTrue);
    gem.y = gem.targetY;
    layer.update(0.01);
    expect(layer.liveSparkCount, 4);
    expect(gem.juiceFalling, isFalse);
    for (var i = 0; i < 5; i++) {
      layer.update(0.01);
      expect(layer.liveSparkCount, 4);
      expect(layer.busy, isFalse);
    }
    layer.update(0.3);
    expect(layer.liveSparkCount, 0);
    expect(layer.busy, isFalse);
    // 같은 인스턴스도 다시 실제로 떨어졌을 때만 새 착지 방출.
    gem.y = gem.targetY - board.tileSize;
    layer.update(0.01);
    gem.y = gem.targetY;
    layer.update(0.01);
    expect(layer.liveSparkCount, 3);
  });

  test('refill hook and pooled gem reset keep visual flags local', () {
    final board = MatchBoardLogic(rows: 1, cols: 1);
    board.refillBoard();
    final gem = board.getGem(0, 0)!;
    expect(gem.juiceRefillPending, isTrue);
    gem.juiceFalling = true;
    gem.reset(
      id: 7,
      color: 2,
      kind: GemKind.normal,
      row: 0,
      col: 0,
      x: 0,
      y: 0,
      targetX: 0,
      targetY: 0,
    );
    expect(gem.juiceRefillPending, isFalse);
    expect(gem.juiceFalling, isFalse);
  });

  test(
    'time glyph atlas fades, remounts and stays out of callout lane',
    () async {
      final game = MatchBoardGame();
      final layer = BoardJuiceLayer()..game = game;
      for (var mount = 0; mount < 2; mount++) {
        layer.onMount();
        layer.onTimeBonus(1.5);
        layer.update(0.24);
        final early = await pixels(layer);
        expect(early.alpha, greaterThan(0));
        expect(early.top, greaterThan(game.board.tileSize * 2));
        layer.update(0.48);
        final late = await pixels(layer);
        expect(late.alpha, lessThan(early.alpha));
        expect(late.alpha, greaterThan(0));
        layer.update(0.09);
        expect((await pixels(layer)).alpha, 0);
        expect(layer.busy, isFalse);
        layer.onRemove();
      }
    },
  );

  test(
    'score glyphs fit board edges and remain below active combo callout',
    () async {
      final game = MatchBoardGame();
      final board = game.board;
      board.setGeometry(x: 40, y: 40, tile: 48);
      final layer = BoardJuiceLayer()..game = game;
      layer.onMount();
      layer.onGemsRemoved(
        [(row: 0, col: 0, color: 2)],
        bigMatch: true,
        hasSpecial: false,
        combo: 5,
        gained: 1234567890,
        pattern: MatchJuicePattern.five,
      );
      layer.update(0.3);
      final result = await pixels(layer);
      expect(result.alpha, greaterThan(0));
      expect(
        layer.liveSparkCount,
        lessThanOrEqualTo(BoardJuiceLayer.maxSparks),
      );
      layer.update(0.6);
      expect(layer.busy, isFalse);
      layer.onRemove();
    },
  );

  test('timed bonus keeps existing cap and zero-room semantics', () {
    final game = MatchBoardGame(gameMode: JewelGameMode.timed);
    game.timeRemaining = game.maxTimeSecondsForMode - 0.5;
    game.board.onTimedModeTimeBonus!(3);
    expect(game.timeRemaining, game.maxTimeSecondsForMode);
    game.board.onTimedModeTimeBonus!(3);
    expect(game.timeRemaining, game.maxTimeSecondsForMode);
  });
}

Future<({int alpha, int top})> pixels(BoardJuiceLayer layer) async {
  final recorder = ui.PictureRecorder();
  layer.render(ui.Canvas(recorder));
  final picture = recorder.endRecording();
  final image = await picture.toImage(512, 512);
  final data = (await image.toByteData())!;
  var alpha = 0;
  var top = 512;
  for (var i = 3; i < data.lengthInBytes; i += 4) {
    final value = data.getUint8(i);
    alpha += value;
    if (value > 0) top = min(top, (i ~/ 4) ~/ 512);
  }
  image.dispose();
  picture.dispose();
  return (alpha: alpha, top: top);
}
