import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stonematch/game/jewel_game_mode.dart';
import 'package:stonematch/game/match_board_game.dart';
import 'package:stonematch/game/match_board_logic.dart';
import 'package:stonematch/game/stage_challenge.dart';
import 'package:stonematch/services/game_settings.dart';
import 'package:stonematch/utils/storage_helper.dart';

Set<int> _colors(MatchBoardLogic board) => {
  for (var r = 0; r < board.rows; r++)
    for (var c = 0; c < board.cols; c++)
      if (board.getGem(r, c) case final gem?) gem.color,
};

void main() {
  test('color count rule: level mode from the set level, others stay 6', () {
    const flags = GameplayFlags(seventhColorFromLevel: 10);
    expect(flags.colorCountFor(progressionMode: true, level: 9), 6);
    expect(flags.colorCountFor(progressionMode: true, level: 10), 7);
    expect(flags.colorCountFor(progressionMode: true, level: 30), 7);
    expect(flags.colorCountFor(progressionMode: false, level: 10), 6);
    expect(
      const GameplayFlags().colorCountFor(progressionMode: true, level: 99),
      6,
    );
  });

  test('a 7 color board actually uses the 7th color', () {
    final board = MatchBoardLogic(rows: 8, cols: 8, colorCount: 7)
      ..setGeometry(x: 0, y: 0, tile: 56);
    final seen = <int>{};
    for (var i = 0; i < 5; i++) {
      board.generateFreshBoard(withIntroFill: false);
      seen.addAll(_colors(board));
    }
    expect(seen, {1, 2, 3, 4, 5, 6, 7});
  });

  test('challenge color target cycles through 7 colors', () {
    final colors = <int>{
      for (var level = 1; level <= 200; level++)
        ?StageChallenge.forLevel(level, colorCount: 7)?.color,
    };
    expect(colors, contains(7));
  });

  group('game', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await StorageHelper.init();
      GameSettings.sfxMuted = true;
      GameSettings.bgmMuted = true;
      GameplayFlags.current = const GameplayFlags(seventhColorFromLevel: 10);
    });
    tearDown(() => GameplayFlags.current = const GameplayFlags());

    Future<MatchBoardGame> mount(
      WidgetTester tester,
      JewelGameMode mode,
    ) async {
      await tester.binding.setSurfaceSize(const Size(468, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final game = MatchBoardGame(gameMode: mode);
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: GameWidget(
              game: game,
              overlayBuilderMap: {
                for (final name in const [
                  'IntroBlock',
                  'PauseMenu',
                  'TimeUp',
                  'NoMoves',
                  'LevelUp',
                  'LevelCelebration',
                  'StageInventory',
                ])
                  name: (_, _) => const SizedBox.shrink(),
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

    testWidgets('level mode: 6 colors at level 9, 7 from level 10', (
      tester,
    ) async {
      final game = await mount(tester, JewelGameMode.progression);
      expect(game.board.colorCount, 6);

      game.levelUpToLevel = 9;
      game.continueAfterLevelUp();
      expect(game.progressionLevel, 9);
      expect(game.board.colorCount, 6);

      game.levelUpToLevel = 10;
      game.continueAfterLevelUp();
      expect(game.board.colorCount, 7);
      expect(game.stageChallenge?.color ?? 1, inInclusiveRange(1, 7));

      // NoMoves 새 보드는 같은 판이라 색 수를 유지한다.
      game.newBoard();
      expect(game.board.colorCount, 7);

      // 다시 하기는 레벨 1로 돌아가 6색.
      game.restartRound();
      expect(game.board.colorCount, 6);
    });

    testWidgets('timed mode stays 6 colors', (tester) async {
      GameplayFlags.current = const GameplayFlags(seventhColorFromLevel: 1);
      final game = await mount(tester, JewelGameMode.timed);
      expect(game.board.colorCount, 6);
      game.restartRound();
      expect(game.board.colorCount, 6);
      expect(_colors(game.board).every((c) => c <= 6), isTrue);
    });
  });
}
