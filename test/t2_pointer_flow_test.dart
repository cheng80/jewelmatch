import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stonematch/game/match_board_game.dart';
import 'package:stonematch/game/components/match_board_renderer.dart';
import 'package:stonematch/game/match_board_logic.dart';
import 'package:stonematch/services/game_settings.dart';
import 'package:stonematch/utils/storage_helper.dart';

void fill(MatchBoardLogic board, {bool valid = false}) {
  for (var r = 0; r < 8; r++) {
    for (var c = 0; c < 8; c++) {
      board.setGem(
        r,
        c,
        board.createGem(r, c, (r + c) % 6 + 1, GemKind.normal),
      );
    }
  }
  if (valid) {
    for (final p in [(6, 0, 2), (7, 0, 5), (7, 1, 2), (7, 2, 2), (7, 3, 4)]) {
      board.getGem(p.$1, p.$2)!.color = p.$3;
    }
  }
  board.introFillInProgress = false;
  board.introFillPaused = false;
  board.state = 'idle';
  board.inputLocked = false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageHelper.init();
    GameSettings.sfxMuted = true;
    GameSettings.bgmMuted = true;
  });

  Future<MatchBoardGame> mount(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(468, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final game = MatchBoardGame();
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: GameWidget(
            game: game,
            overlayBuilderMap: {
              'IntroBlock': (_, _) => const SizedBox.shrink(),
              'PauseMenu': (_, _) => const SizedBox.shrink(),
            },
          ),
        ),
      );
      await game.toBeLoaded();
      await game.ready();
    });
    await tester.pump();
    game.pauseEngine();
    return game;
  }

  testWidgets('Flame tree removal and reattachment rebuilds gem atlas', (
    tester,
  ) async {
    final game = await mount(tester);
    final renderer = game.world.children.whereType<MatchBoardRenderer>().single;
    expect(renderer.hasGemAtlas, isTrue);
    renderer.removeFromParent();
    await tester.runAsync(() => game.ready());
    expect(renderer.hasGemAtlas, isFalse);
    await tester.runAsync(() async {
      await game.world.add(renderer);
      await game.ready();
    });
    expect(renderer.hasGemAtlas, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets(
    'pause and resumed input reset simple automatic hint inactivity',
    (tester) async {
      final game = await mount(tester);
      fill(game.board, valid: true);
      game.board.update(5.1);
      expect(game.board.hintCellA, isNotNull);
      game.pauseGame();
      expect(game.board.hintCellA, isNull);
      expect(game.board.idleHintElapsed, 0);
      game.resumeGame();
      game.pauseEngine();
      game.board.update(4.9);
      expect(game.board.hintCellA, isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    },
  );

  testWidgets(
    'real pointer swipe during swapSettle cannot become removal drag',
    (tester) async {
      final game = await mount(tester);
      fill(game.board, valid: true);
      expect(game.board.trySwap(6, 0, 7, 0), isTrue);
      final origin =
          game.board.cellToPixel(7, 0) +
          Offset(game.board.tileSize / 2, game.board.tileSize / 2);
      final pointer = await tester.startGesture(origin);
      await pointer.moveBy(const Offset(30, 0));
      await pointer.moveBy(const Offset(15, 0));
      await tester.pump();
      expect(game.board.hasInvalidDragFeedback, isFalse);
      game.board.update(0.12);
      expect(game.board.state, 'removing');
      await pointer.moveBy(const Offset(12, 0));
      await tester.pump();
      expect(game.board.hasInvalidDragFeedback, isFalse);
      await pointer.up();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    },
  );

  testWidgets('real invalid pointer hold and release has no delayed bump', (
    tester,
  ) async {
    final game = await mount(tester);
    fill(game.board);
    final gem = game.board.getGem(0, 0)!;
    final origin =
        game.board.cellToPixel(0, 0) +
        Offset(game.board.tileSize / 2, game.board.tileSize / 2);
    final pointer = await tester.startGesture(origin);
    await pointer.moveBy(const Offset(30, 0));
    await pointer.moveBy(const Offset(10, 0));
    await tester.pump();
    expect(game.board.hasInvalidDragFeedback, isTrue);
    expect(gem.x, greaterThan(gem.targetX));
    for (var i = 0; i < 30; i++) {
      game.board.update(1 / 60);
    }
    await pointer.up();
    await tester.pump();
    expect(game.board.hasInvalidDragFeedback, isFalse);
    game.board.update(0.16);
    expect(gem.x, gem.targetX);
    game.board.update(0.09);
    expect(gem.x, gem.targetX);
    expect(gem.bumpT, lessThan(0));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
