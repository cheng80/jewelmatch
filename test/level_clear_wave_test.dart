import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stonematch/game/jewel_game_mode.dart';
import 'package:stonematch/game/match_board_game.dart';
import 'package:stonematch/game/match_board_logic.dart';
import 'package:stonematch/services/game_settings.dart';
import 'package:stonematch/utils/storage_helper.dart';
import 'package:stonematch/views/overlays/level_celebration_overlay.dart';
import 'package:stonematch/views/overlays/level_clear_wave.dart';

class _CountingGame extends MatchBoardGame {
  _CountingGame() : super(gameMode: JewelGameMode.progression);
  int completions = 0;

  @override
  void showLevelUpPopupAfterCelebration() {
    completions++;
    super.showLevelUpPopupAfterCelebration();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageHelper.init();
    GameSettings.sfxMuted = true;
    GameSettings.bgmMuted = true;
  });

  test(
    'diagonal charge precedes burst and every surviving cell emits once',
    () {
      final game = _clear();
      game.board.setGem(0, 1, null);
      final before = _snapshot(game);
      final wave = LevelClearWave(game);
      wave.advance(0.119);
      expect(wave.litCells, 0);
      wave.advance(0.12);
      expect(wave.litCells, 1);
      expect(wave.burstCells, 0);
      wave.advance(0.19);
      expect(wave.burstCells, 1);
      wave.advance(0.21);
      expect(wave.litCells, 2); // diagonal 1 has one empty cell
      wave.advance(3);
      expect(wave.litCells, 63);
      expect(wave.burstCells, 63);
      expect(wave.liveSparkCount, 0);
      wave.advance(3);
      expect(wave.burstCells, 63);
      expect(_snapshot(game), before);
      expect(game.paused, isTrue);
      wave.dispose();
    },
  );

  test(
    'special gems remain intact and no removal or time reward is invoked',
    () {
      final game = _clear();
      final board = game.board;
      for (var col = 0; col < GemKind.values.length; col++) {
        board.getGem(2, col)!.kind = GemKind.values[col];
      }
      var removed = 0;
      board.onRemovalStarted = (_) => removed++;
      final before = _snapshot(game);
      final wave = LevelClearWave(game);
      for (var frame = 0; frame <= 180; frame++) {
        wave.advance(frame / 60);
      }
      expect(removed, 0);
      expect(_snapshot(game), before);
      wave.dispose();
    },
  );

  test(
    'atlas renders at board geometry and expires without residual pixels',
    () async {
      final game = _clear();
      game.board.setGeometry(x: 75, y: 90, tile: 30);
      final wave = LevelClearWave(game);
      wave.advance(0.15);
      final early = await _pixels(wave);
      expect(early.count, greaterThan(0));
      expect(early.minX, greaterThanOrEqualTo(75));
      expect(early.maxX, lessThan(105));
      expect(early.minY, greaterThanOrEqualTo(90));
      expect(early.maxY, lessThan(120));
      wave.advance(3);
      expect((await _pixels(wave)).count, 0);
      wave.dispose();
    },
  );

  testWidgets(
    'normal celebration stays paused then completes exactly once at 3s',
    (tester) async {
      final game = _clear(level: 6);
      final before = _snapshot(game);
      await tester.pumpWidget(_host(game));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2999));
      expect(game.completions, 0);
      expect(game.paused, isTrue);
      expect(_snapshot(game), before);
      await tester.pump(const Duration(milliseconds: 1));
      expect(game.completions, 1);
      expect(game.overlays.isActive('LevelCelebration'), isFalse);
      expect(game.overlays.isActive('LevelUp'), isTrue);
      expect(game.overlays.isActive('StageInventory'), isTrue);
      expect(game.isPlaying, isFalse);
      expect(game.paused, isTrue);
      expect(_snapshot(game), before);
      await tester.pump(const Duration(seconds: 10));
      expect(game.completions, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'reduce motion completes immediately without a wave or delayed popup',
    (tester) async {
      final game = _clear();
      final before = _snapshot(game);
      await tester.pumpWidget(_host(game, reduced: true));
      expect(game.completions, 1);
      expect(game.overlays.isActive('LevelUp'), isTrue);
      expect(find.byType(LevelClearWaveView), findsNothing);
      expect(_snapshot(game), before);
      await tester.pump(const Duration(seconds: 4));
      expect(game.completions, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('enabling reduce motion during wave finalizes once', (
    tester,
  ) async {
    final game = _clear();
    await tester.pumpWidget(_host(game));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpWidget(_host(game, reduced: true));
    expect(game.completions, 1);
    expect(game.overlays.isActive('LevelUp'), isTrue);
    await tester.pump(const Duration(seconds: 4));
    expect(game.completions, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'disposing halfway cancels completion and releases visual resources',
    (tester) async {
      final game = _clear();
      await tester.pumpWidget(_host(game));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
      expect(game.completions, 0);
      expect(game.overlays.isActive('LevelUp'), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('restart and a new clear reject stale widget completion', (
    tester,
  ) async {
    final game = _clear();
    await tester.pumpWidget(_host(game));
    await tester.pump(const Duration(milliseconds: 500));
    final oldAttempt = game.levelCelebrationAttempt;
    game.restartRound();
    _triggerClear(game);
    expect(game.levelCelebrationAttempt, isNot(oldAttempt));
    await tester.pump(const Duration(seconds: 4));
    expect(game.completions, 0);
    expect(game.overlays.isActive('LevelCelebration'), isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_host(game, reduced: true));
    expect(game.completions, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('replacing game in same widget finishes only the current game', (
    tester,
  ) async {
    final first = _clear();
    await tester.pumpWidget(_host(first));
    await tester.pump(const Duration(milliseconds: 500));
    final second = _clear();
    await tester.pumpWidget(_host(second, reduced: true));
    expect(first.completions, 0);
    expect(second.completions, 1);
    await tester.pump(const Duration(seconds: 4));
    expect(second.completions, 1);
    await tester.pumpWidget(const SizedBox());
  });

  test('repeat completion cannot reopen closed inventory or award twice', () {
    final game = _clear(level: 6);
    final before = _snapshot(game);
    game.showLevelUpPopupAfterCelebration();
    game.overlays.remove('StageInventory');
    game.showLevelUpPopupAfterCelebration();
    expect(game.overlays.isActive('StageInventory'), isFalse);
    expect(_snapshot(game), before);
    game.continueAfterLevelUp();
    game.showLevelUpPopupAfterCelebration();
    expect(game.overlays.isActive('LevelUp'), isFalse);
    expect(game.isPlaying, isTrue);
    expect(game.paused, isFalse);
  });
}

_CountingGame _clear({int level = 1}) {
  final game = _CountingGame();
  for (final key in [
    'IntroBlock',
    'LevelCelebration',
    'LevelUp',
    'StageInventory',
    'NoMoves',
  ]) {
    game.overlays.addEntry(key, (_, _) => const SizedBox());
  }
  for (var row = 0; row < 8; row++) {
    for (var col = 0; col < 8; col++) {
      game.board.setGem(
        row,
        col,
        game.board.createGem(row, col, (row * 2 + col) % 6 + 1, GemKind.normal),
      );
    }
  }
  game.board.setGeometry(x: 20, y: 130, tile: 40);
  game.progressionLevel = level;
  _triggerClear(game);
  return game;
}

void _triggerClear(MatchBoardGame game) {
  game.board.score = game.progressionTargetScore;
  game.board.introFillInProgress = false;
  game.isPlaying = true;
  game.update(0);
}

Widget _host(MatchBoardGame game, {bool reduced = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: LevelCelebrationOverlay(game: game),
  ),
);

Map<String, Object?> _snapshot(MatchBoardGame game) {
  final b = game.board;
  final s = b.stats;
  return {
    'score': b.score,
    'combo': [b.lastCombo, b.maxCombo],
    'state': b.state,
    'time': game.timeRemaining,
    'stats': [
      s.validSwaps,
      s.matchGroups,
      s.removedGems,
      s.specialGemsCreated,
      s.specialGemsActivated,
      Map.of(s.removedByKind),
      Map.of(s.specialCreatedByKind),
      Map.of(s.specialActivatedByKind),
    ],
    'inventory': game.runInventory.snapshot(),
    'rewards': game.latestStageRewards,
    'hints': game.hintBadgeCount,
    'cells': [
      for (final row in b.cells)
        [
          for (final g in row)
            if (g == null)
              null
            else
              [
                g.id,
                g.kind,
                g.color,
                g.x,
                g.y,
                g.targetX,
                g.targetY,
                g.juiceRefillPending,
                g.juiceFalling,
              ],
        ],
    ],
  };
}

Future<({int count, int minX, int maxX, int minY, int maxY})> _pixels(
  LevelClearWave wave,
) async {
  final recorder = ui.PictureRecorder();
  wave.paint(Canvas(recorder));
  final picture = recorder.endRecording();
  final image = picture.toImageSync(400, 500);
  final bytes = (await image.toByteData())!.buffer.asUint8List();
  var count = 0, minX = 400, minY = 500, maxX = -1, maxY = -1;
  for (var y = 0; y < 500; y++) {
    for (var x = 0; x < 400; x++) {
      if (bytes[(y * 400 + x) * 4 + 3] == 0) continue;
      count++;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
  }
  image.dispose();
  picture.dispose();
  return (count: count, minX: minX, maxX: maxX, minY: minY, maxY: maxY);
}
