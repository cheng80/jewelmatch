import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stonematch/game/components/board_atlas.dart';
import 'package:stonematch/game/components/match_board_renderer.dart';
import 'package:stonematch/game/components/match_game_hud.dart';
import 'package:stonematch/game/jewel_game_mode.dart';
import 'package:stonematch/game/match_board_game.dart';
import 'package:stonematch/game/match_board_logic.dart';
import 'package:stonematch/services/game_settings.dart';
import 'package:stonematch/utils/storage_helper.dart';

const _allOn = GameplayFlags(
  timeRewardT1: true,
  timeGem: true,
  multiplierGem: true,
);

/// 칸마다 다른 색이라 매치가 없고, 리필 색이 1000가지라 연쇄가 사실상 나지 않는다.
/// 보드 난수는 날짜 시드라 결과가 매번 같다.
MatchBoardLogic _board({
  GameplayFlags flags = _allOn,
  bool timed = true,
  List<int>? bonuses,
}) {
  final board = MatchBoardLogic(
    rows: 8,
    cols: 8,
    colorCount: 1000,
    timedModeTimeRewardScale: 0.6,
    onTimedModeTimeBonus: bonuses?.add,
  )..setGeometry(x: 0, y: 0, tile: 56);
  board
    ..flags = flags
    ..timedModeRules = timed
    ..startDailyBoard('2026-09-24');
  for (var r = 0; r < 8; r++) {
    for (var c = 0; c < 8; c++) {
      board.setGem(r, c, board.createGem(r, c, 10 + r * 8 + c, GemKind.normal));
    }
  }
  return board;
}

void _paint(MatchBoardLogic board, int row, int col, int color) {
  board.getGem(row, col)!.color = color;
}

/// 0행 앞 [length]칸을 색 1로 만들고 해소를 시작한다(연쇄 콤보 1).
void _startRowMatch(MatchBoardLogic board, int length, {int combo = 0}) {
  for (var c = 0; c < length; c++) {
    _paint(board, 0, c, 1);
  }
  board
    ..combo = combo
    ..state = 'checking';
  board.advanceResolutionStep(); // 매치 찾기, 특수 보석 생성
  board.advanceResolutionStep(); // 제거, 점수, 시간 보상
}

void _settle(MatchBoardLogic board) {
  for (var i = 0; i < 400 && board.state != 'idle'; i++) {
    board.advanceResolutionStep();
  }
  expect(board.state, 'idle');
}

/// 하이퍼를 (0,0)에 두고 (0,1)과 바꿔 색 1을 모두 지운다. 지우는 수는 [extra] + 2(대상, 하이퍼).
/// 색 1은 짝수 행, 짝수 열 칸에만 둬서 줄 매치가 생기지 않는다.
int _hyperSwapRemoving(MatchBoardLogic board, int extra) {
  final cells = [
    for (var r = 0; r < 8; r += 2)
      for (var c = 0; c < 8; c += 2)
        if (r != 0 || c != 0) (r, c),
  ];
  for (final (r, c) in cells.take(extra)) {
    _paint(board, r, c, 1);
  }
  _paint(board, 0, 1, 1);
  board.setGem(0, 0, board.createGem(0, 0, 0, GemKind.hyper));
  final before = board.stats.removedGems;
  expect(board.trySwap(0, 0, 0, 1), isTrue);
  _settle(board);
  return board.stats.removedGems - before;
}

List<String> _snapshot(MatchBoardLogic board) => [
  for (var r = 0; r < board.rows; r++)
    for (var c = 0; c < board.cols; c++)
      '${board.getGem(r, c)?.color}:${board.getGem(r, c)?.kind.name}:'
          '${board.getGem(r, c)?.bonus.name}',
];

void _playFirstMove(MatchBoardLogic board) {
  final move = board.getAllValidMoves().first;
  expect(board.trySwap(move.a.x, move.a.y, move.b.x, move.b.y), isTrue);
  _settle(board);
}

MatchBoardLogic _dailyBoard({GameplayFlags flags = const GameplayFlags()}) {
  final board = MatchBoardLogic(rows: 8, cols: 8)
    ..setGeometry(x: 0, y: 0, tile: 56)
    ..flags = flags
    ..timedModeRules = true
    ..startDailyBoard('2026-09-24');
  board.generateFreshBoard(withIntroFill: false);
  return board;
}

/// 배지 시트(256×128) drawImageRect만 센다. saveLayer는 쓰지 않아야 한다.
class _BadgeSpy implements ui.Canvas {
  final sources = <ui.Rect>[];
  @override
  dynamic noSuchMethod(Invocation invocation) {
    expect(invocation.memberName, isNot(#saveLayer));
    if (invocation.memberName == #drawImageRect) {
      // 보석은 구운 atlas의 drawRawAtlas라 drawImageRect는 배지뿐이다.
      sources.add(invocation.positionalArguments[1] as ui.Rect);
    }
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('T1 time reward', () {
    test('plain 3 match at combo 1 gives 0 seconds', () {
      final bonuses = <int>[];
      _startRowMatch(_board(bonuses: bonuses), 3);
      expect(bonuses, isEmpty);
    });

    test('switch off, level mode, 4 match and combo 2 keep BR-050', () {
      for (final setup in <(GameplayFlags, bool, int, int)>[
        (const GameplayFlags(), true, 3, 0),
        (_allOn, false, 3, 0),
        (_allOn, true, 4, 0),
        (_allOn, true, 3, 1),
      ]) {
        final bonuses = <int>[];
        _startRowMatch(
          _board(flags: setup.$1, timed: setup.$2, bonuses: bonuses),
          setup.$3,
          combo: setup.$4,
        );
        expect(bonuses, [1], reason: '$setup');
      }
    });
  });

  group('Time gem', () {
    test('clearing it adds 5 seconds to the step reward', () {
      final bonuses = <int>[];
      final board = _board(bonuses: bonuses);
      board.getGem(0, 2)!.bonus = GemBonus.time;
      _startRowMatch(board, 3);
      // T1 기본 0초 + Time 보석 5초.
      expect(bonuses, [5]);
      expect(board.stats.timeGemsCollected, 1);
    });

    test(
      'used as special material it loses the bonus and still gives time',
      () {
        final bonuses = <int>[];
        final board = _board(bonuses: bonuses);
        // 4개 매치의 생성 칸은 가운데 앞(0,1)이다.
        board.getGem(0, 1)!.bonus = GemBonus.time;
        _startRowMatch(board, 4);
        expect(board.getGem(0, 1)!.kind, GemKind.bomb);
        expect(board.getGem(0, 1)!.bonus, GemBonus.none);
        expect(bonuses, [6]);
        expect(board.stats.timeGemsCollected, 1);
      },
    );

    test('a swap move clearing 10 or more creates one, 9 does not', () {
      final small = _board();
      expect(_hyperSwapRemoving(small, 7), 9);
      expect(small.countBonusGems(GemBonus.time), 0);

      final big = _board();
      expect(_hyperSwapRemoving(big, 8), 10);
      expect(big.countBonusGems(GemBonus.time), 1);
    });

    test('at most 2 on the board', () {
      final board = _board();
      board.getGem(7, 7)!.bonus = GemBonus.time;
      board.getGem(7, 5)!.bonus = GemBonus.time;
      expect(_hyperSwapRemoving(board, 8), 10);
      expect(board.stats.timeGemsCollected, 0);
      expect(board.countBonusGems(GemBonus.time), 2);
    });

    test('bonus follows the gem through fate shuffle', () {
      final board = MatchBoardLogic(rows: 8, cols: 8)
        ..setGeometry(x: 0, y: 0, tile: 56)
        ..startDailyBoard('2026-09-24');
      board.generateFreshBoard(withIntroFill: false);
      final gem = board.getGem(3, 3)!..bonus = GemBonus.time;
      final color = gem.color;
      expect(board.shuffleOrdinaryGemsPreservingSpecials(), isTrue);
      expect(board.countBonusGems(GemBonus.time), 1);
      final moved = [
        for (final row in board.cells)
          for (final g in row)
            if (g!.bonus == GemBonus.time) g,
      ].single;
      expect(moved.color, color);
    });

    test('NoMoves shuffle keeps the count, new round clears it', () {
      final board = _dailyBoard(flags: _allOn);
      board.getGem(2, 2)!.bonus = GemBonus.time;
      board.getGem(4, 4)!.bonus = GemBonus.multiplier;
      board.shuffle();
      expect(board.countBonusGems(GemBonus.time), 1);
      expect(board.countBonusGems(GemBonus.multiplier), 1);
      board.scoreMultiplier = 3;
      board.generateFreshBoard(withIntroFill: false);
      expect(board.countBonusGems(GemBonus.time), 0);
      expect(board.countBonusGems(GemBonus.multiplier), 0);
      expect(board.scoreMultiplier, 1);
    });

    test('H2 flow keeps Time gem seconds inside the 3 second cap', () {
      final bonuses = <int>[];
      final board = _board(bonuses: bonuses);
      board.getGem(5, 5)!.bonus = GemBonus.time;
      board.getGem(6, 6)!.bonus = GemBonus.time;
      board.setGem(3, 3, board.createGem(3, 3, 0, GemKind.hyper));
      board.setGem(3, 4, board.createGem(3, 4, 0, GemKind.hyper));
      expect(board.trySwap(3, 3, 3, 4), isTrue);
      _settle(board);
      expect(board.stats.timeGemsCollected, 2);
      expect(
        bonuses.fold<int>(0, (a, b) => a + b),
        MatchBoardLogic.hyperPairTimeCapSeconds,
      );
    });
  });

  group('Multiplier gem', () {
    test('m=1 threshold 12 creates Multiplier first, then Time elsewhere', () {
      final below = _board();
      expect(_hyperSwapRemoving(below, 9), 11);
      expect(below.countBonusGems(GemBonus.multiplier), 0);
      expect(below.countBonusGems(GemBonus.time), 1);

      final at = _board();
      expect(_hyperSwapRemoving(at, 10), 12);
      expect(at.countBonusGems(GemBonus.multiplier), 1);
      expect(at.countBonusGems(GemBonus.time), 1);
    });

    test('threshold grows by 4 per level, none at x8 or when one exists', () {
      final m2Below = _board()..scoreMultiplier = 2;
      expect(_hyperSwapRemoving(m2Below, 13), 15);
      expect(m2Below.countBonusGems(GemBonus.multiplier), 0);

      final m2At = _board()..scoreMultiplier = 2;
      expect(_hyperSwapRemoving(m2At, 14), 16);
      expect(m2At.countBonusGems(GemBonus.multiplier), 1);

      final max = _board()..scoreMultiplier = 8;
      expect(_hyperSwapRemoving(max, 14), 16);
      expect(max.countBonusGems(GemBonus.multiplier), 0);

      final existing = _board();
      existing.getGem(7, 7)!.bonus = GemBonus.multiplier;
      expect(_hyperSwapRemoving(existing, 12), 14);
      expect(existing.countBonusGems(GemBonus.multiplier), 1);
    });

    test('switch off consumes no board random and places nothing', () {
      final off = _board(flags: const GameplayFlags());
      final level = _board(timed: false);
      final plain = _board(flags: const GameplayFlags(), timed: false);
      for (final board in [off, level, plain]) {
        expect(_hyperSwapRemoving(board, 14), 16);
        expect(board.countBonusGems(GemBonus.time), 0);
        expect(board.countBonusGems(GemBonus.multiplier), 0);
      }
      expect(_snapshot(off), _snapshot(plain));
      expect(_snapshot(level), _snapshot(plain));
    });

    test('clearing it raises m, applied from the next score', () {
      final board = _board();
      board.getGem(0, 0)!.bonus = GemBonus.multiplier;
      _startRowMatch(board, 3);
      expect(board.lastRemovalScore, 100);
      expect(board.scoreMultiplier, 2);
      expect(board.stats.maxMultiplier, 2);
      board.removeMarkedGems({'5:5': true});
      expect(board.lastRemovalScore, 200);
    });

    test('multiplies special bonus but not Speed Bonus', () {
      final board = _board()..scoreMultiplier = 3;
      board.setGem(5, 5, board.createGem(5, 5, 9, GemKind.bomb));
      board.removeMarkedGems({'5:5': true});
      // (100 + 폭탄 500) × 3.
      expect(board.lastRemovalScore, 1800);

      final swap = _board()..scoreMultiplier = 3;
      swap.onValidSwapBonus = () => 200;
      _paint(swap, 0, 0, 1);
      _paint(swap, 0, 1, 1);
      _paint(swap, 1, 2, 1);
      expect(swap.trySwap(1, 2, 0, 2), isTrue);
      expect(swap.score, 200);
    });

    test('H2 score cap applies after the multiplier', () {
      final plain = _board();
      final boosted = _board()..scoreMultiplier = 2;
      for (final board in [plain, boosted]) {
        board.setGem(3, 3, board.createGem(3, 3, 0, GemKind.hyper));
        board.setGem(3, 4, board.createGem(3, 4, 0, GemKind.hyper));
        expect(board.trySwap(3, 3, 3, 4), isTrue);
        board.advanceResolutionStep();
      }
      // 64개 3150 + 하이퍼 2개 2400 = 5550. ×2는 11100이라 상한 10000.
      expect(plain.score, 5550);
      expect(boosted.score, MatchBoardLogic.hyperPairScoreCap);
    });
  });

  test('round_end params only for switched-on timed rounds', () {
    final board = _board();
    board.stats
      ..timeGemsCollected = 2
      ..timeGemSeconds = 7
      ..maxMultiplier = 3;
    expect(board.bonusGemEventParams, {
      'time_gems': 2,
      'time_gem_seconds': 7,
      'max_multiplier': 3,
    });
    expect(_board(flags: const GameplayFlags()).bonusGemEventParams, isEmpty);
    expect(_board(timed: false).bonusGemEventParams, isEmpty);
  });

  test(
    'switched on: same day and same input give the same board and score',
    () {
      final a = _dailyBoard(flags: _allOn);
      final b = _dailyBoard(flags: _allOn);
      // 이 날 보드는 8번째 수가 10개를 지워 Time 보석이 생긴다.
      for (var i = 0; i < 10; i++) {
        _playFirstMove(a);
        _playFirstMove(b);
        expect(_snapshot(a), _snapshot(b), reason: 'after move ${i + 1}');
      }
      expect(a.countBonusGems(GemBonus.time), 1);
      expect(a.score, b.score);
      expect(a.scoreMultiplier, b.scoreMultiplier);
    },
  );

  group('game wiring', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await StorageHelper.init();
      GameSettings.sfxMuted = true;
      GameSettings.bgmMuted = true;
    });

    MatchBoardGame game(JewelGameMode mode) {
      final g = MatchBoardGame(gameMode: mode);
      g.overlays.addEntry('IntroBlock', (_, _) => const SizedBox());
      g.onGameResize(Vector2(390, 750));
      return g;
    }

    test('only the timed mode turns on bonus rules', () {
      expect(game(JewelGameMode.timed).board.timedModeRules, isTrue);
      expect(game(JewelGameMode.progression).board.timedModeRules, isFalse);
      expect(game(JewelGameMode.simple).board.timedModeRules, isFalse);
    });

    test('Time gem seconds count what the 90 second cap lets in', () {
      final g = game(JewelGameMode.timed);
      g.timeRemaining = 88;
      g.board.lastTimeGemSeconds = 5;
      g.board.onTimedModeTimeBonus!(6);
      expect(g.timeRemaining, 90);
      expect(g.board.stats.timeGemSeconds, 2);
    });

    test('HUD shows xm from 2 and pops when it rises', () {
      final g = game(JewelGameMode.timed);
      final h = MatchGameHud(
        onPausePressed: () {},
        onHintPressed: () {},
        onTutorialPressed: () {},
        onRankingPressed: () {},
      )..game = g;
      h.onGameResize(g.size);
      h.update(0);
      expect(h.debugReadFeedback()['multiplierText'], isNull);
      g.board.scoreMultiplier = 2;
      h.update(.016);
      expect(h.debugReadFeedback()['multiplierText'], '×2');
      expect(h.debugReadFeedback()['multiplierPunch'], greaterThan(.9));
      final rec = ui.PictureRecorder();
      h.render(ui.Canvas(rec));
      rec.endRecording().dispose();
      h.update(1);
      expect(h.debugReadFeedback()['multiplierPunch'], 0);
    });

    test(
      'renderer draws one badge per bonus gem from the board atlas',
      () async {
        final g = game(JewelGameMode.timed);
        final board = g.board..setGeometry(x: 16, y: 16, tile: 48);
        for (var r = 0; r < 8; r++) {
          for (var c = 0; c < 8; c++) {
            board.setGem(
              r,
              c,
              board.createGem(r, c, c % 6 + 1, GemKind.normal),
            );
          }
        }
        board.getGem(2, 2)!.bonus = GemBonus.time;
        board.getGem(5, 5)!.bonus = GemBonus.multiplier;
        final renderer = MatchBoardRenderer(logic: board)..game = g;
        await renderer.onLoad();
        renderer.onMount();
        final spy = _BadgeSpy();
        renderer.render(spy);
        final atlas = await BoardAtlas.load();
        expect(spy.sources, [atlas.frames['badge_0'], atlas.frames['badge_1']]);
        expect(spy.sources.first.size, const ui.Size(128, 128));
        expect(renderer.gemAtlasDrawCalls, 1);
        renderer.onRemove();
      },
    );
  });
}
