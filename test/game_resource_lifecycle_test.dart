import 'dart:ui' as ui;

import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stonematch/game/components/board_juice_layer.dart';
import 'package:stonematch/game/components/match_board_renderer.dart';
import 'package:stonematch/game/components/match_game_hud.dart';
import 'package:stonematch/game/components/special_effect_burst.dart';
import 'package:stonematch/game/jewel_game_mode.dart';
import 'package:stonematch/game/match_board_game.dart';
import 'package:stonematch/game/match_board_logic.dart';
import 'package:stonematch/resources/asset_paths.dart';
import 'package:stonematch/services/game_settings.dart';
import 'package:stonematch/utils/storage_helper.dart';

// Only replace native BGM calls in pause. Loading, updates and teardown use
// production code, including the real world and viewport component trees.
class _ResourceGame extends MatchBoardGame {
  _ResourceGame() : super(gameMode: JewelGameMode.progression);

  int updates = 0;

  @override
  void pauseGame() {
    isPlaying = false;
    pauseEngine();
  }

  @override
  void update(double dt) {
    updates++;
    super.update(dt);
  }
}

// Observe the actual images submitted for rendering, without relying on atlas
// dimensions or adding production accessors for private resources.
class _AtlasCanvas implements ui.Canvas {
  final images = <ui.Image>{};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #drawRawAtlas) {
      images.add(invocation.positionalArguments.first as ui.Image);
    }
    if (invocation.memberName == #getSaveCount) return 1;
    return null;
  }
}

Future<_ResourceGame> _mountGame(WidgetTester tester) async {
  // Start widget loading outside fake async so image decoding can finish.
  // Each controlled factory creates a fresh game, matching GameView ownership.
  late _ResourceGame game;
  await tester.runAsync(() async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: GameWidget<_ResourceGame>.controlled(
          gameFactory: () => game = _ResourceGame(),
          overlayBuilderMap: {
            for (final name in [
              'IntroBlock',
              'PauseMenu',
              'NoMoves',
              'TimeUp',
              'LevelCelebration',
              'LevelUp',
            ])
              name: (_, _) => const SizedBox(),
          },
        ),
      ),
    );
    await game.toBeLoaded();
  });
  await tester.pump();
  await tester.runAsync(() => game.ready());
  game.board.generateFreshBoard(withIntroFill: false);
  await tester.pump(const Duration(milliseconds: 16));
  return game;
}

Map<String, Set<ui.Image>> _renderedAtlases(_ResourceGame game) {
  final juice = game.world.children.whereType<BoardJuiceLayer>().single;
  final gems = game.world.children.whereType<MatchBoardRenderer>().single;
  final hud = game.camera.viewport.children.whereType<MatchGameHud>().single;
  juice.onRemovalStarted({'0:0': true});
  juice.onTimeBonus(1.5);
  juice.update(0.02);
  final juiceCanvas = _AtlasCanvas();
  final gemCanvas = _AtlasCanvas();
  final hudCanvas = _AtlasCanvas();
  juice.render(juiceCanvas);
  gems.render(gemCanvas);
  hud.render(hudCanvas);
  expect(
    juiceCanvas.images,
    hasLength(2),
    reason: 'particles and numeric text',
  );
  expect(gemCanvas.images, hasLength(1));
  expect(hudCanvas.images, hasLength(1));
  expect(hud.debugGlowReady, isTrue);
  expect(gems.hasGemAtlas, isTrue);
  return {
    'numeric and particle': juiceCanvas.images,
    'gem': gemCanvas.images,
    'HUD': hudCanvas.images,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageHelper.init();
    GameSettings.sfxMuted = true;
    GameSettings.bgmMuted = true;
  });

  testWidgets(
    'controlled widget exit releases rendered atlases and stops paused ticker once',
    (tester) async {
      final game = await _mountGame(tester);
      final hud = game.camera.viewport.children
          .whereType<MatchGameHud>()
          .single;
      final renderer = game.world.children
          .whereType<MatchBoardRenderer>()
          .single;
      final juice = game.world.children.whereType<BoardJuiceLayer>().single;
      final atlases = _renderedAtlases(game);
      final sharedJewel = Flame.images.fromCache(AssetPaths.boardAtlas);
      final disposeCounts = Map<ui.Image, int>.identity();
      final previousOnDispose = ui.Image.onDispose;
      ui.Image.onDispose = (image) {
        previousOnDispose?.call(image);
        disposeCounts.update(image, (count) => count + 1, ifAbsent: () => 1);
      };
      addTearDown(() {
        ui.Image.onDispose = previousOnDispose;
        // A failing regression must not leave its ticker in the next test.
        if (hud.isMounted) hud.onRemove();
      });

      hud.debugTapButton(hud.debugReadButtonRects()['pause']!.center);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final press = hud.debugReadFeedback()['pressPunch'];
      expect(press, inExclusiveRange(0, 1));
      final updates = game.updates;
      final score = game.board.score;
      final seconds = game.timeRemaining;

      await tester.pumpWidget(const SizedBox());
      for (final entry in atlases.entries) {
        for (final image in entry.value) {
          expect(image.debugDisposed, isTrue, reason: '${entry.key} atlas');
          expect(disposeCounts[image], 1, reason: '${entry.key} disposed once');
        }
      }
      expect(hud.debugGlowReady, isFalse);
      expect(renderer.hasGemAtlas, isFalse);
      expect([
        hud.isMounted,
        renderer.isMounted,
        juice.isMounted,
      ], everyElement(isFalse));
      expect(game.children, isEmpty);
      expect(game.hasLifecycleEvents, isFalse);

      await tester.pump(const Duration(milliseconds: 80));
      expect(hud.debugReadFeedback()['pressPunch'], press);
      expect(game.updates, updates);
      expect(game.board.score, score);
      expect(game.timeRemaining, seconds);
      expect(tester.binding.transientCallbackCount, 0);

      // GameWidget already finalized removal. Repeated cleanup must not double
      // dispose owned images or invalidate another screen's cached asset.
      game.onRemove();
      game.onRemove();
      expect(game.hasLifecycleEvents, isFalse);
      for (final images in atlases.values) {
        for (final image in images) {
          expect(disposeCounts[image], 1);
        }
      }
      expect(sharedJewel.debugDisposed, isFalse);
      expect(Flame.images.fromCache(AssetPaths.boardAtlas), same(sharedJewel));
      // 보드 아틀라스도 공유 캐시 소유라 게임 퇴장으로 해제되지 않는다.
      expect(
        Flame.images.fromCache(AssetPaths.boardAtlas).debugDisposed,
        isFalse,
      );
    },
  );

  testWidgets(
    'new controlled game can render with shared assets after previous exit',
    (tester) async {
      final first = await _mountGame(tester);
      final oldAtlases = _renderedAtlases(first);
      final sharedJewel = Flame.images.fromCache(AssetPaths.boardAtlas);
      first.isPlaying = false;
      await tester.pumpWidget(const SizedBox());

      final next = await _mountGame(tester);
      expect(next, isNot(same(first)));
      final newAtlases = _renderedAtlases(next);
      expect(Flame.images.fromCache(AssetPaths.boardAtlas), same(sharedJewel));
      expect(sharedJewel.debugDisposed, isFalse);
      for (final name in oldAtlases.keys) {
        expect(oldAtlases[name]!.every((image) => image.debugDisposed), isTrue);
        expect(
          newAtlases[name]!.every((image) => !image.debugDisposed),
          isTrue,
        );
        expect(newAtlases[name]!.intersection(oldAtlases[name]!), isEmpty);
      }
      // Submit a real canvas too: a cached source disposed by teardown would
      // otherwise remain hidden by the capture canvas above.
      final recorder = ui.PictureRecorder();
      next.render(ui.Canvas(recorder));
      recorder.endRecording().dispose();
      next.isPlaying = false;
      await tester.pumpWidget(const SizedBox());
      for (final images in newAtlases.values) {
        expect(images.every((image) => image.debugDisposed), isTrue);
      }
    },
  );

  testWidgets(
    'active pool removal and parent removal safely share the teardown queue',
    (tester) async {
      final game = await _mountGame(tester);
      game.board.setGem(3, 3, game.board.createGem(3, 3, 1, GemKind.bomb));
      expect(game.board.triggerSpecialCell(3, 3), isTrue);
      await tester.runAsync(() async {
        game.update(0.01);
        await game.ready();
      });
      final burst = game.world.children.whereType<SpecialEffectBurst>().single;
      expect(burst.debugGlowReady, isTrue);
      expect(game.hasActiveVisualEffects, isTrue);
      // _specialEffectPool.clear() queues this child first; the game then
      // queues the whole world. Neither removal may strand or double-free it.
      game.isPlaying = false;
      await tester.pumpWidget(const SizedBox());
      expect(burst.isMounted, isFalse);
      expect(burst.debugGlowReady, isFalse);
      expect(game.hasActiveVisualEffects, isFalse);
      expect(game.hasLifecycleEvents, isFalse);
      game.onRemove();
      expect(game.children, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
