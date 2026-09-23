import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/game/jewel_game_mode.dart';
import 'package:stonematch/game/match_board_game.dart';
import 'package:stonematch/game/match_board_logic.dart';
import 'package:stonematch/game/speed_bonus.dart';

void main() {
  group('SpeedBonus', () {
    List<int> swaps(SpeedBonus speed, int count, {double gap = 1}) {
      final bonuses = <int>[];
      for (var i = 0; i < count; i++) {
        if (i > 0) speed.advance(gap);
        bonuses.add(speed.onValidSwap());
      }
      return bonuses;
    }

    test('starts on the third fast swap with +200', () {
      final speed = SpeedBonus(enabled: true);
      expect(swaps(speed, 3), [0, 0, 200]);
      expect(speed.tier, 1);
    });

    test('rises by 100 per fast swap and caps at +1000', () {
      final speed = SpeedBonus(enabled: true);
      final bonuses = swaps(speed, 13);
      expect(bonuses.sublist(2, 11), [
        200,
        300,
        400,
        500,
        600,
        700,
        800,
        900,
        1000,
      ]);
      expect(bonuses.sublist(11), [1000, 1000]);
      expect(speed.peakTier, SpeedBonus.maxTier);
      expect(speed.totalBonus, bonuses.reduce((a, b) => a + b));
    });

    test('a slow swap resets the chain to zero', () {
      final speed = SpeedBonus(enabled: true);
      swaps(speed, 4);
      speed.advance(SpeedBonus.windowSeconds + 0.01);
      expect(speed.tier, 0);
      expect(speed.onValidSwap(), 0);
      expect(swaps(speed, 2).last, 200);
      expect(speed.peakTier, 2);
    });

    test('gap exactly at the window still counts as fast', () {
      final speed = SpeedBonus(enabled: true);
      expect(swaps(speed, 3, gap: SpeedBonus.windowSeconds).last, 200);
    });

    test('paused time is not counted because advance is not called', () {
      final speed = SpeedBonus(enabled: true);
      speed.onValidSwap();
      speed.advance(1);
      // 일시정지 동안 벽시계는 흘러도 게임은 advance를 부르지 않는다.
      speed.onValidSwap();
      speed.advance(3);
      expect(speed.onValidSwap(), 200);
    });

    test('disabled mode never awards or tracks', () {
      final speed = SpeedBonus(enabled: false);
      expect(swaps(speed, 6, gap: 0.1), everyElement(0));
      expect(speed.peakTier, 0);
      expect(speed.totalBonus, 0);
    });

    test('reset clears round totals', () {
      final speed = SpeedBonus(enabled: true);
      swaps(speed, 5);
      speed.reset();
      expect(speed.peakTier, 0);
      expect(speed.totalBonus, 0);
      expect(speed.onValidSwap(), 0);
    });
  });

  group('Speed Bonus score integration', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    int swapOnce(MatchBoardGame game) {
      final board = game.board;
      _setRows(board, _validMoveRows);
      board.state = 'idle';
      board.inputLocked = false;
      final move = board.getAllValidMoves().first;
      final before = board.score;
      expect(board.trySwap(move.a.x, move.a.y, move.b.x, move.b.y), isTrue);
      game.speedBonus.advance(1);
      return board.score - before;
    }

    test('timed mode adds bonus on valid swap without combo multiplier', () {
      final game = MatchBoardGame(gameMode: JewelGameMode.timed);
      game.board.combo = 4;
      final gains = [for (var i = 0; i < 5; i++) swapOnce(game)];
      expect(gains, [0, 0, 200, 300, 400]);
    });

    test('invalid swap adds nothing', () {
      var calls = 0;
      final board = MatchBoardLogic(rows: 8, cols: 8)
        ..onValidSwapBonus = () {
          calls++;
          return 999;
        };
      _setRows(board, _validMoveRows);
      expect(board.trySwap(7, 6, 7, 7), isFalse);
      expect(board.score, 0);
      expect(calls, 0);
    });

    for (final mode in [JewelGameMode.progression, JewelGameMode.simple]) {
      test('${mode.name} mode gets no speed bonus', () {
        final game = MatchBoardGame(gameMode: mode);
        final gains = [for (var i = 0; i < 5; i++) swapOnce(game)];
        expect(gains, everyElement(0));
        expect(game.speedBonus.enabled, isFalse);
      });
    }
  });
}

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
