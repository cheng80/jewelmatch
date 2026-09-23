import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stonematch/game/daily_seed.dart';
import 'package:stonematch/game/jewel_game_mode.dart';
import 'package:stonematch/game/match_board_game.dart';
import 'package:stonematch/game/match_board_logic.dart';
import 'package:stonematch/services/game_settings.dart';
import 'package:stonematch/utils/storage_helper.dart';

MatchBoardLogic _dailyBoard(String key) {
  final board = MatchBoardLogic(rows: 8, cols: 8)
    ..setGeometry(x: 0, y: 0, tile: 56)
    ..startDailyBoard(key);
  board.generateFreshBoard(withIntroFill: false);
  return board;
}

List<String> _snapshot(MatchBoardLogic board) => [
  for (var r = 0; r < board.rows; r++)
    for (var c = 0; c < board.cols; c++)
      '${board.getGem(r, c)?.color}:${board.getGem(r, c)?.kind.name}',
];

void _settle(MatchBoardLogic board) {
  for (var i = 0; i < 2000; i++) {
    if (board.state == 'idle' && !board.inputLocked) return;
    board.update(1 / 60);
  }
  fail('board did not settle');
}

/// 첫 유효 이동으로 스왑하고 보드가 멈출 때까지 진행한다.
void _playFirstMove(MatchBoardLogic board) {
  final move = board.getAllValidMoves().first;
  expect(board.trySwap(move.a.x, move.a.y, move.b.x, move.b.y), isTrue);
  _settle(board);
}

void main() {
  test('day key uses KST midnight', () {
    expect(
      DailySeed.keyFor(DateTime.utc(2026, 9, 23, 14, 59, 59)),
      '2026-09-23',
    );
    expect(DailySeed.keyFor(DateTime.utc(2026, 9, 23, 15)), '2026-09-24');
    expect(DailySeed.keyFor(DateTime.utc(2026, 12, 31, 15)), '2027-01-01');
  });

  test('seed is FNV-1a 32 of the versioned key and xorshift is fixed', () {
    // 값이 바뀌면 이미 나간 날의 보드가 달라진다. 의도한 변경일 때만 고친다.
    expect(DailySeed.seedFor('2026-09-24'), 2062547673);
    final random = DailyRandom(2062547673);
    expect(
      [for (var i = 0; i < 3; i++) random.nextInt(0x100000000)],
      [858232931, 3310917302, 642356049],
    );
  });

  test('same day gives the same start board and refill flow', () {
    final a = _dailyBoard('2026-09-24');
    final b = _dailyBoard('2026-09-24');
    expect(_snapshot(a), _snapshot(b));

    for (var i = 0; i < 4; i++) {
      // 힌트 순서 난수는 보드 흐름을 흐트러뜨리지 않는다.
      a.showHint();
      a.clearHint();
      _playFirstMove(a);
      _playFirstMove(b);
      expect(_snapshot(a), _snapshot(b), reason: 'after move ${i + 1}');
    }
    expect(a.score, b.score);
    expect(a.score, greaterThan(0));
  });

  test('NoMoves shuffle follows the same daily flow', () {
    final a = _dailyBoard('2026-09-24');
    final b = _dailyBoard('2026-09-24');
    a.shuffle();
    b.shuffle();
    expect(_snapshot(a), _snapshot(b));
  });

  test('a different day gives a different board', () {
    expect(
      _snapshot(_dailyBoard('2026-09-24')),
      isNot(_snapshot(_dailyBoard('2026-09-25'))),
    );
  });

  group('timed game', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await StorageHelper.init();
      GameSettings.sfxMuted = true;
      GameSettings.bgmMuted = true;
    });

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

    testWidgets('start and restart use today board; new board does not', (
      tester,
    ) async {
      final game = await mount(tester, JewelGameMode.timed);
      final key = DailySeed.keyFor(DateTime.now());
      final today = _snapshot(_dailyBoard(key));
      expect(game.board.dailyKey, key);
      expect(_snapshot(game.board), today);

      game.newBoard();
      expect(_snapshot(game.board), isNot(today));

      game.restartRound();
      expect(_snapshot(game.board), today);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('simple mode stays random', (tester) async {
      final game = await mount(tester, JewelGameMode.simple);
      expect(game.board.dailyKey, isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
