import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stonematch/game/components/match_game_hud.dart';
import 'package:stonematch/game/jewel_game_mode.dart';
import 'package:stonematch/game/match_board_game.dart';
import 'package:stonematch/game/match_board_models.dart';
import 'package:stonematch/game/stage_challenge.dart';
import 'package:stonematch/services/game_settings.dart';
import 'package:stonematch/utils/storage_helper.dart';

void main() {
  group('StageChallenge.forLevel', () {
    test('only multiples of 4 are challenge stages', () {
      for (final level in [1, 2, 3, 5, 6, 7, 9, 10, 11, 13]) {
        expect(StageChallenge.forLevel(level), isNull, reason: 'level $level');
      }
      for (final level in [4, 8, 12, 16, 40]) {
        expect(StageChallenge.forLevel(level), isNotNull);
      }
    });

    test('kind rotates with k % 3 and targets follow the formulas', () {
      final l4 = StageChallenge.forLevel(4)!; // k=1
      expect(l4.kind, StageChallengeKind.color);
      expect(l4.target, 20);
      expect(l4.color, 1);

      final l8 = StageChallenge.forLevel(8)!; // k=2
      expect(l8.kind, StageChallengeKind.special);
      expect(l8.target, 4);
      expect(l8.color, isNull);

      final l12 = StageChallenge.forLevel(12)!; // k=3
      expect(l12.kind, StageChallengeKind.gems);
      expect(l12.target, 105);

      final l16 = StageChallenge.forLevel(16)!; // k=4
      expect(l16.kind, StageChallengeKind.color);
      expect(l16.target, 35);
      expect(l16.color, 2);
    });

    test('targets are capped and colors wrap deterministically', () {
      expect(StageChallenge.forLevel(4 * 100)!.target, 60); // k=100 color
      expect(StageChallenge.forLevel(4 * 101)!.target, 10); // k=101 special
      expect(StageChallenge.forLevel(4 * 102)!.target, 200); // k=102 gems
      // k=7 → ((7 - 1) ~/ 3) % 6 + 1 = 3
      expect(StageChallenge.forLevel(28)!.color, 3);
      expect(StageChallenge.forLevel(28, colorCount: 5)!.color, 3);
      // k=16 → 5 % 5 + 1 = 1
      expect(StageChallenge.forLevel(64, colorCount: 5)!.color, 1);
    });

    test('color challenges cycle through every color', () {
      final colors = <int>[];
      for (var level = 4; level <= 4 * 18; level += 4) {
        final c = StageChallenge.forLevel(level);
        if (c?.kind == StageChallengeKind.color) colors.add(c!.color!);
      }
      expect(colors, [1, 2, 3, 4, 5, 6]);
    });
  });

  group('NoMoves during a challenge stage', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await StorageHelper.init();
      await StorageHelper.erase();
      GameSettings.sfxMuted = true;
    });

    MatchBoardGame progressionGame(int level) {
      final game = MatchBoardGame(gameMode: JewelGameMode.progression);
      for (final name in ['IntroBlock', 'LevelCelebration', 'NoMoves']) {
        game.overlays.addEntry(name, (_, _) => const SizedBox());
      }
      game.progressionLevel = level;
      game.board.introFillInProgress = false;
      game.board.state = 'idle';
      game.isPlaying = true;
      return game;
    }

    // 검수 R3 P1-1: NoMoves 새 보드가 판 통계를 지워 진행도가 0이 되던 문제.
    test('new board keeps challenge progress', () {
      final game = progressionGame(12); // 보석 105개
      for (var i = 0; i < 100; i++) {
        game.board.stats.recordGemRemoved(GemKind.normal, 1);
      }
      expect(game.stageChallenge!.progress(game.board.stats), 100);
      game.overlays.add('NoMoves');
      game.newBoard();
      expect(game.stageChallenge!.progress(game.board.stats), 100);
    });

    test('shuffle keeps challenge progress', () {
      final game = progressionGame(12);
      for (var i = 0; i < 100; i++) {
        game.board.stats.recordGemRemoved(GemKind.normal, 1);
      }
      game.overlays.add('NoMoves');
      game.shuffleBoard();
      expect(game.stageChallenge!.progress(game.board.stats), 100);
    });
  });

  group('progress', () {
    test('color counts only normal gems of the target color', () {
      final challenge = StageChallenge.forLevel(4)!;
      final stats = MatchBoardGameStats()
        ..recordGemRemoved(GemKind.normal, 1)
        ..recordGemRemoved(GemKind.normal, 1)
        ..recordGemRemoved(GemKind.normal, 2)
        ..recordGemRemoved(GemKind.bomb, 1);
      expect(challenge.progress(stats), 2);
      expect(challenge.isComplete(stats), isFalse);
    });

    test('special and gems use activation and removal totals, capped', () {
      final stats = MatchBoardGameStats();
      for (var i = 0; i < 6; i++) {
        stats.recordSpecialActivated(GemKind.bomb);
      }
      final special = StageChallenge.forLevel(8)!;
      expect(special.progress(stats), 4);
      expect(special.isComplete(stats), isTrue);

      for (var i = 0; i < 50; i++) {
        stats.recordGemRemoved(GemKind.normal, 3);
      }
      expect(StageChallenge.forLevel(12)!.progress(stats), 50);
    });
  });

  group('game clear', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await StorageHelper.init();
      await StorageHelper.erase();
      GameSettings.sfxMuted = true;
    });

    MatchBoardGame progressionGame(int level) {
      final game = MatchBoardGame(gameMode: JewelGameMode.progression);
      game.overlays.addEntry('IntroBlock', (_, _) => const SizedBox());
      game.overlays.addEntry('LevelCelebration', (_, _) => const SizedBox());
      game.progressionLevel = level;
      game.board.introFillInProgress = false;
      game.board.state = 'idle';
      game.isPlaying = true;
      return game;
    }

    test('challenge stage ignores target score until goal is met', () {
      final game = progressionGame(8);
      game.board.score = game.progressionTargetScore * 2;
      game.update(0);
      expect(game.isPlaying, isTrue);

      for (var i = 0; i < 4; i++) {
        game.board.stats.recordSpecialActivated(GemKind.star);
      }
      game.update(0);
      expect(game.isPlaying, isFalse);
      expect(game.levelUpToLevel, 9);
      expect(game.overlays.isActive('LevelCelebration'), isTrue);
    });

    test('entering a challenge stage shows a short notice', () {
      final game = progressionGame(7);
      game.board.score = game.progressionTargetScore;
      game.update(0);
      expect(game.levelUpToLevel, 8);
      game.continueAfterLevelUp();
      expect(game.stageChallenge?.kind, StageChallengeKind.special);
      expect(game.itemFeedbackText, 'Challenge Stage');
    });

    test('normal level still clears on target score', () {
      final game = progressionGame(5);
      expect(game.stageChallenge, isNull);
      game.board.score = game.progressionTargetScore;
      game.update(0);
      expect(game.isPlaying, isFalse);
    });

    test('HUD shows challenge progress text', () {
      final game = progressionGame(12);
      game.onGameResize(Vector2(390, 750));
      final hud = MatchGameHud(
        onPausePressed: () {},
        onHintPressed: () {},
        onTutorialPressed: () {},
      )..game = game;
      hud.onGameResize(game.size);
      hud.update(0);
      expect(hud.debugReadFeedback()['challengeText'], 'Gems 0/105');

      game.board.stats.recordGemRemoved(GemKind.normal, 2);
      hud.update(0);
      expect(hud.debugReadFeedback()['challengeText'], 'Gems 1/105');

      // 색 목표(아이콘 경로)도 그리기에서 예외가 없어야 한다.
      game.progressionLevel = 4;
      hud.update(0);
      expect(hud.debugReadFeedback()['challengeText'], '0/20');
      final recorder = ui.PictureRecorder();
      hud.render(ui.Canvas(recorder));
      recorder.endRecording().dispose();
    });
  });
}
