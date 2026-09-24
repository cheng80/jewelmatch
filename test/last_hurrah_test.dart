import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stonematch/game/jewel_game_mode.dart';
import 'package:stonematch/game/last_hurrah.dart';
import 'package:stonematch/game/match_board_game.dart';
import 'package:stonematch/game/match_board_logic.dart';
import 'package:stonematch/game/match_board_qa_bridge.dart';
import 'package:stonematch/services/game_settings.dart';
import 'package:stonematch/services/records/records_store.dart';
import 'package:stonematch/utils/storage_helper.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageHelper.init();
    GameSettings.sfxMuted = true;
    GameSettings.bgmMuted = true;
    // restartRound가 BGM을 멈출 때 오디오 플러그인 채널을 부른다.
    for (final name in [
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers.global',
    ]) {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        MethodChannel(name),
        (_) async => null,
      );
    }
  });

  group('LastHurrah rules', () {
    test('fires top row first, left to right', () {
      final board = _board();
      _putSpecial(board, 4, 1, GemKind.row);
      _putSpecial(board, 2, 6, GemKind.bomb);
      _putSpecial(board, 2, 3, GemKind.bomb);

      expect(LastHurrah.nextSpecial(board), const Point(2, 3));
      final run = LastHurrah(board, random: Random(1));
      run.update(LastHurrah.startDelaySeconds);

      expect(run.activations, 1);
      expect(board.pendingRemovalSet, contains('2:3'));
      expect(board.pendingRemovalSet, isNot(contains('2:6')));
      expect(board.getGem(2, 6)!.kind, GemKind.bomb);
    });

    test('specials hit by a blast chain in the same activation', () {
      final board = _board();
      _putSpecial(board, 2, 3, GemKind.bomb);
      _putSpecial(board, 2, 4, GemKind.star); // bomb 범위 안
      _putSpecial(board, 6, 1, GemKind.hyper); // 두 범위 밖
      final run = LastHurrah(board, random: Random(1));
      for (var frame = 0; frame < 60 * 8 && !run.done; frame++) {
        board.update(1 / 60);
        run.update(1 / 60);
      }

      expect(run.done, isTrue);
      expect(run.activations, 2);
      expect(board.stats.specialGemsActivated, 3);
      expect(board.stats.specialGemsCreated, 0);
      expect(LastHurrah.hasSpecial(board), isFalse);
      expect(run.scoreAdded, greaterThan(0));
    });

    // 권장안 회귀: 기존 규칙에서는 이 보드들 중 여럿이 마무리 연쇄로 새 특수 보석을 만들어 다시 발동했다.
    test('finale never creates or fires new specials, and m stays', () {
      for (var day = 1; day <= 20; day++) {
        final board = MatchBoardLogic(rows: 8, cols: 8)
          ..startDailyBoard('2026-08-${day.toString().padLeft(2, '0')}')
          ..generateFreshBoard(withIntroFill: false)
          ..scoreMultiplier = 3;
        _putSpecial(board, 1, 2, GemKind.bomb);
        _putSpecial(board, 4, 5, GemKind.hyper);
        _putSpecial(board, 6, 1, GemKind.star);
        board.getGem(7, 7)!.bonus = GemBonus.multiplier;

        final run = LastHurrah(board, random: Random(day))..finishInstantly();

        expect(board.stats.specialGemsCreated, 0, reason: 'day $day');
        expect(run.activations, lessThanOrEqualTo(3), reason: 'day $day');
        expect(board.stats.specialGemsActivated, 3, reason: 'day $day');
        expect(board.scoreMultiplier, 3, reason: 'day $day');
        expect(LastHurrah.hasSpecial(board), isFalse, reason: 'day $day');
        expect(board.lastHurrahRules, isFalse, reason: 'day $day');
      }
    });

    test('Last Hurrah cascades clear 4+ matches without making specials', () {
      MatchBoardLogic fourInRow() {
        final board = _board();
        for (var col = 0; col < 4; col++) {
          board.setGem(7, col, board.createGem(7, col, 2, GemKind.normal));
        }
        return board;
      }

      final normal = fourInRow();
      expect(normal.beginNextResolutionCycle(), isTrue);
      expect(normal.stats.specialGemsCreated, 1);

      final finale = fourInRow()
        ..beginLastHurrahRules(comboMultiplier: false, cascadeSteps: 1);
      expect(finale.beginNextResolutionCycle(), isTrue);
      expect(finale.stats.specialGemsCreated, 0);
      expect(
        finale.pendingRemovalSet!.keys,
        containsAll(['7:0', '7:1', '7:2', '7:3']),
      );
      expect(finale.lastHurrahCascadeBudget, 0);

      // 연쇄 상한을 다 쓰면 남은 매치는 해소하지 않고 멈춘다.
      final capped = fourInRow()
        ..beginLastHurrahRules(comboMultiplier: false, cascadeSteps: 0);
      expect(capped.beginNextResolutionCycle(), isFalse);
      expect(capped.state, 'idle');
      expect(capped.score, 0);
      expect(capped.getGem(7, 0)!.color, 2);
    });

    test(
      'Multiplier gems cleared in Last Hurrah score at m without raising it',
      () {
        MatchBoardLogic withMultiplier() {
          final board = _board()
            ..scoreMultiplier = 2
            ..combo = 1;
          board.getGem(7, 0)!.bonus = GemBonus.multiplier;
          return board;
        }

        const cells = {'7:0': true, '7:1': true, '7:2': true};
        final normal = withMultiplier()..removeMarkedGems(cells);
        expect(normal.scoreMultiplier, 3);

        final finale = withMultiplier()
          ..beginLastHurrahRules(comboMultiplier: false, cascadeSteps: 20)
          ..removeMarkedGems(cells);
        expect(finale.lastRemovalScore, 200);
        expect(finale.scoreMultiplier, 2);
        expect(finale.stats.maxMultiplier, 1);
      },
    );

    test('cap reached finishes the rest instantly', () {
      final board = _board();
      _putSpecial(board, 1, 1, GemKind.row);
      _putSpecial(board, 6, 6, GemKind.col);
      _putSpecial(board, 3, 4, GemKind.hyper);
      final run = LastHurrah(board, random: Random(2));

      run.update(LastHurrah.maxSeconds);

      expect(run.done, isTrue);
      expect(run.activations, greaterThanOrEqualTo(3));
      expect(LastHurrah.hasSpecial(board), isFalse);
      expect(board.state, 'idle');
      expect(board.consumeSpecialEffectEvents(), isEmpty);
      expect(run.eventParams, {
        'specials_count': run.activations,
        'score_added': board.score,
      });
    });

    // R-3: 유저 입력이 아닌 발동은 최고 한 수에 넣지 않는다.
    test('Last Hurrah activations are not counted as a best move', () {
      final board = _board();
      _putSpecial(board, 2, 3, GemKind.bomb);

      final run = LastHurrah(board, random: Random(1))..finishInstantly();

      expect(board.score, greaterThan(0));
      expect(board.stats.bestMoveScore, 0);
      expect(board.stats.trackMoves, isTrue);
      expect(run.done, isTrue);
    });

    // R-10: 시간 0 순간 진행 중이던 유저 연쇄 점수는 score_added에서 뺀다.
    test('score_added starts at the first activation', () {
      final board = _board();
      _putSpecial(board, 2, 3, GemKind.bomb);
      final run = LastHurrah(board, random: Random(1));
      board.score += 500; // 시작 뒤 끝난 유저 연쇄
      run.finishInstantly();

      expect(run.scoreBefore, 500);
      expect(run.eventParams['score_added'], board.score - 500);
    });

    test('hyper color is a seeded pick among colors left on board', () {
      final board = _board();
      _putSpecial(board, 3, 4, GemKind.hyper);
      final colors = <int>{
        for (final row in board.cells)
          for (final gem in row)
            if (gem != null && gem.kind == GemKind.normal) gem.color,
      };

      final a = LastHurrah.pickHyperColor(board, Random(9));
      final b = LastHurrah.pickHyperColor(board, Random(9));
      expect(a, b);
      expect(colors, contains(a));
    });

    test('combo switch applies from the first activation, restored after', () {
      final board = _board();
      board.combo = 3;
      board.removeMarkedGems({'7:0': true, '7:1': true, '7:2': true});
      expect(board.lastRemovalScore, 300);

      board.comboScoreMultiplier = false;
      board.removeMarkedGems({'6:0': true, '6:1': true, '6:2': true});
      expect(board.lastRemovalScore, 100);

      // 기본(권장안)은 꺼짐. 시간 0 순간 진행 중이던 유저 연쇄는 첫 발동 전까지 보통 규칙이다.
      final fresh = _board();
      _putSpecial(fresh, 2, 2, GemKind.bomb);
      final run = LastHurrah(fresh);
      expect(fresh.comboScoreMultiplier, isTrue);
      expect(fresh.lastHurrahRules, isFalse);
      run.update(LastHurrah.startDelaySeconds);
      expect(run.activations, 1);
      expect(fresh.comboScoreMultiplier, isFalse);
      expect(fresh.lastHurrahRules, isTrue);
      run.finishInstantly();
      expect(fresh.comboScoreMultiplier, isTrue);
      expect(fresh.lastHurrahRules, isFalse);

      final on = _board()
        ..flags = const GameplayFlags(lastHurrahComboMultiplier: true);
      _putSpecial(on, 2, 2, GemKind.bomb);
      final onRun = LastHurrah(on)..update(LastHurrah.startDelaySeconds);
      expect(on.comboScoreMultiplier, isTrue);
      expect(on.lastHurrahRules, isTrue);
      onRun.finishInstantly();
      expect(on.comboScoreMultiplier, isTrue);
      expect(on.lastHurrahRules, isFalse);
    });
  });

  group('timed mode flow', () {
    test('locks input during Last Hurrah and opens TimeUp once after', () {
      final game = _timedGame();
      _putSpecial(game.board, 2, 3, GemKind.bomb);
      _putSpecial(game.board, 5, 1, GemKind.row);
      final hints = game.remainingHints;

      game.timeRemaining = 0.01;
      game.update(0.02);

      expect(game.lastHurrahActive, isTrue);
      expect(game.readSimulationState()['lastHurrahActive'], isTrue);
      expect(game.timeUp, isFalse);
      expect(game.isPlaying, isFalse);
      expect(game.overlays.isActive('TimeUp'), isFalse);

      final gem = game.board.getGem(0, 0);
      game.handleBoardTap(5, 5);
      expect(game.board.selected, isNull);
      expect(game.handleBoardSwipe(5, 5, 15, 5, 0, 1), isFalse);
      expect(game.board.getGem(0, 0), same(gem));
      game.requestHint();
      expect(game.remainingHints, hints);
      game.pauseGame();
      expect(game.overlays.isActive('PauseMenu'), isFalse);

      final before = game.board.score;
      var timeUpFrames = 0;
      for (var frame = 0; frame < 60 * 8; frame++) {
        game.update(1 / 60);
        if (game.overlays.isActive('TimeUp')) timeUpFrames++;
        if (!game.timeUp) {
          expect(game.overlays.isActive('TimeUp'), isFalse);
        }
      }

      expect(game.timeUp, isTrue);
      expect(game.lastHurrahActive, isFalse);
      expect(game.readSimulationState()['lastHurrahActive'], isFalse);
      expect(game.overlays.isActive('TimeUp'), isTrue);
      expect(timeUpFrames, greaterThan(0));
      expect(game.timeRemaining, 0, reason: 'no time reward while finishing');
      expect(game.board.score, greaterThan(before));
      expect(LastHurrah.hasSpecial(game.board), isFalse);
      // 기록 반영(round_end와 같은 지점)은 마무리 뒤 최종 점수로 한 번.
      expect(RecordsStore.load().totalScore, game.board.score);
      game.update(1 / 60);
      expect(RecordsStore.load().totalScore, game.board.score);
    });

    test('no specials goes straight to TimeUp', () {
      final game = _timedGame();
      game.timeRemaining = 0.01;
      game.update(0.02);

      expect(game.lastHurrahActive, isFalse);
      expect(game.timeUp, isTrue);
      expect(game.overlays.isActive('TimeUp'), isTrue);
    });

    test('reduced motion computes instantly and opens TimeUp', () {
      binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final game = _timedGame();
      _putSpecial(game.board, 2, 3, GemKind.bomb);
      final before = game.board.score;

      game.timeRemaining = 0.01;
      game.update(0.02);

      expect(game.lastHurrahActive, isFalse);
      expect(game.timeUp, isTrue);
      expect(game.overlays.isActive('TimeUp'), isTrue);
      expect(game.board.score, greaterThan(before));
      expect(LastHurrah.hasSpecial(game.board), isFalse);
    });

    test('going to background finishes instantly without PauseMenu', () {
      final game = _timedGame();
      _putSpecial(game.board, 2, 3, GemKind.bomb);
      game.timeRemaining = 0.01;
      game.update(0.02);
      expect(game.lastHurrahActive, isTrue);

      game.lifecycleStateChange(AppLifecycleState.paused);

      expect(game.lastHurrahActive, isFalse);
      expect(game.timeUp, isTrue);
      expect(game.overlays.isActive('TimeUp'), isTrue);
      expect(game.overlays.isActive('PauseMenu'), isFalse);
      expect(LastHurrah.hasSpecial(game.board), isFalse);
    });

    test('level mode keeps the old TimeUp without Last Hurrah', () {
      final game = MatchBoardGame(gameMode: JewelGameMode.progression);
      _prepare(game);
      _putSpecial(game.board, 2, 3, GemKind.bomb);
      final before = game.board.score;

      game.timeRemaining = 0.01;
      game.update(0.02);

      expect(game.lastHurrahActive, isFalse);
      expect(game.timeUp, isTrue);
      expect(game.board.score, before);
      expect(game.board.getGem(2, 3)!.kind, GemKind.bomb);
    });

    // R-2: 일시정지 다시 하기도 판을 한 번 반영한다.
    test('restarting an unfinished round commits it to records once', () {
      final game = _timedGame();
      game.board.score = 4200;
      game.restartRound();
      expect(RecordsStore.load().totalScore, 4200);

      game.board.score = 1000;
      game.restartRound();
      expect(RecordsStore.load().totalScore, 5200);
    });

    test('restart after TimeUp does not commit again', () {
      final game = _timedGame();
      game.board.score = 3000;
      game.timeRemaining = 0.01;
      game.update(0.02);
      expect(game.timeUp, isTrue);
      expect(RecordsStore.load().totalScore, 3000);

      game.restartRound();
      expect(RecordsStore.load().totalScore, 3000);
    });

    test('restart clears an unfinished Last Hurrah', () {
      final game = _timedGame();
      _putSpecial(game.board, 2, 3, GemKind.bomb);
      game.timeRemaining = 0.01;
      game.update(0.02);
      expect(game.lastHurrahActive, isTrue);
      game.update(LastHurrah.startDelaySeconds);
      expect(game.board.lastHurrahRules, isTrue);

      game.restartRound();

      expect(game.lastHurrahActive, isFalse);
      expect(game.timeUp, isFalse);
      expect(game.board.comboScoreMultiplier, isTrue);
      expect(game.board.lastHurrahRules, isFalse);
    });
  });
}

MatchBoardGame _timedGame() {
  final game = MatchBoardGame(gameMode: JewelGameMode.timed)
    ..lastHurrahRandom = Random(5);
  _prepare(game);
  return game;
}

void _prepare(MatchBoardGame game) {
  for (final name in ['IntroBlock', 'PauseMenu', 'NoMoves', 'TimeUp']) {
    game.overlays.addEntry(name, (_, _) => const SizedBox());
  }
  _setRows(game.board, _validMoveRows);
  game.board.setGeometry(x: 0, y: 0, tile: 10);
  game.board.introFillInProgress = false;
}

MatchBoardLogic _board() {
  final board = MatchBoardLogic(rows: 8, cols: 8);
  _setRows(board, _validMoveRows);
  return board;
}

/// 원래 색을 유지해 즉시 매치를 만들지 않는다.
void _putSpecial(MatchBoardLogic board, int row, int col, GemKind kind) {
  final color = kind == GemKind.hyper ? 0 : board.getGem(row, col)!.color;
  board.setGem(row, col, board.createGem(row, col, color, kind));
}

const _validMoveRows = [
  [1, 2, 1, 4, 5, 6, 1, 2],
  [2, 1, 4, 5, 6, 1, 2, 3],
  [3, 4, 3, 6, 1, 2, 3, 4],
  [4, 3, 6, 1, 2, 3, 4, 5],
  [5, 6, 1, 2, 3, 4, 5, 6],
  [6, 1, 2, 3, 4, 5, 6, 1],
  [1, 2, 3, 4, 5, 6, 1, 2],
  [2, 3, 4, 5, 6, 1, 2, 3],
];

void _setRows(MatchBoardLogic board, List<List<int>> rows) {
  for (var row = 0; row < rows.length; row++) {
    for (var col = 0; col < rows[row].length; col++) {
      board.setGem(
        row,
        col,
        board.createGem(row, col, rows[row][col], GemKind.normal),
      );
    }
  }
}
