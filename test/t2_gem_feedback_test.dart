import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/game/match_board_logic.dart';
import 'package:stonematch/game/match_board_game.dart';
import 'package:stonematch/game/jewel_game_mode.dart';

void main() {
  test(
    'automatic hint is simple-only after 5 idle seconds without spending inventory',
    () {
      for (final mode in JewelGameMode.values) {
        final game = MatchBoardGame(gameMode: mode);
        final board = game.board;
        board.generateFreshBoard(withIntroFill: false);
        final remaining = game.remainingHints;
        board.update(4.9);
        expect(board.hintCellA, isNull);
        board.update(0.11);
        expect(board.hintCellA != null, mode == JewelGameMode.simple);
        expect(game.remainingHints, remaining);
        final a = board.hintCellA;
        board.update(10);
        expect(board.hintCellA, a, reason: '유휴 힌트가 계속 다른 수로 바뀌지 않는다');
      }
    },
  );

  test(
    'input and board progress restart idle delay; automatic hint clears',
    () {
      final board = MatchBoardLogic(rows: 8, cols: 8)..idleHintsEnabled = true;
      board.generateFreshBoard(withIntroFill: false);
      board.update(4.9);
      board.selectCell(2, 2);
      board.update(0.2);
      expect(board.hintCellA, isNull);
      board.update(4.9);
      expect(board.hintCellA, isNotNull);
      board.handleTap(-1, -1);
      expect(board.hintCellA, isNull);
      board.update(4.9);
      expect(board.hintCellA, isNull);
      board.state = 'checking';
      board.stageTimer = 0.09;
      board.update(0.01);
      board.state = 'idle';
      board.update(0.2);
      expect(board.hintCellA, isNull);
      board.update(5);
      expect(board.hintCellA, isNotNull);
      board.idleHintsEnabled = false;
      board.update(0.01);
      expect(board.hintCellA, isNull);
    },
  );

  test('intro and drag do not accumulate automatic hint delay', () {
    final board = MatchBoardLogic(rows: 8, cols: 8)..idleHintsEnabled = true;
    board.generateFreshBoard();
    board.introFillPaused = true;
    board.update(10);
    expect(board.hintCellA, isNull);
    expect(board.idleHintElapsed, 0);
    board.generateFreshBoard(withIntroFill: false);
    board.startInvalidDragFeedback(
      row: 1,
      col: 1,
      startX: 84,
      startY: 84,
      currentX: 102,
      currentY: 84,
    );
    board.update(10);
    expect(board.hintCellA, isNull);
    expect(board.swapPreviewCell?.y, 2);
    board.endInvalidDragFeedback();
    expect(board.swapPreviewCell, isNull);
    board.update(0.2);
    board.update(4.9);
    expect(board.hintCellA, isNull);
    board.update(0.2);
    expect(board.hintCellA, isNotNull);
  });

  test(
    'selection feedback callback fires for new selections, not deselection or swap',
    () {
      final board = MatchBoardLogic(rows: 8, cols: 8);
      board.generateFreshBoard(withIntroFill: false);
      var sounds = 0;
      board.onGemSelected = () => sounds++;
      board.handleTap(28, 28);
      expect(sounds, 1);
      board.handleTap(28, 28);
      expect(sounds, 1);
      board.selectCell(2, 2);
      board.selectCell(2, 2);
      expect(sounds, 2);
    },
  );

  test('shuffle preserves score/stats and existing intro completion kind', () {
    final board = MatchBoardLogic(rows: 8, cols: 8);
    board.generateFreshBoard(withIntroFill: false);
    board.score = 1200;
    board.stats.recordValidSwap();
    final stats = board.stats;
    BoardFillIntroKind? completion;
    board.onIntroFillComplete = (kind) => completion = kind;
    board.shuffle();
    expect(board.introFillInProgress, isTrue);
    for (var i = 0; i < 300; i++) {
      board.update(1 / 60);
    }
    expect(completion, BoardFillIntroKind.shuffleRefill);
    expect(board.score, 1200);
    expect(board.stats, same(stats));
    expect(board.hasMatches(), isFalse);
    expect(board.hasAnyValidMove(), isTrue);
  });

  test('valid swap cancels the same gem invalid drag return', () {
    final board = MatchBoardLogic(rows: 3, cols: 3);
    const colors = [
      [1, 2, 1],
      [2, 1, 3],
      [3, 2, 3],
    ];
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 3; c++) {
        board.setGem(r, c, board.createGem(r, c, colors[r][c], GemKind.normal));
      }
    }
    final gem = board.getGem(0, 1)!;
    board.startInvalidDragFeedback(
      row: 0,
      col: 1,
      startX: 84,
      startY: 28,
      currentX: 100,
      currentY: 28,
    );
    board.endInvalidDragFeedback();
    expect(board.trySwap(0, 1, 1, 1), isTrue);
    final beforeX = gem.x;
    final beforeY = gem.y;
    board.update(0.02);
    expect(gem.x, closeTo(beforeX + (gem.targetX - beforeX) * 0.36, 0.0001));
    expect(gem.y, closeTo(beforeY + (gem.targetY - beforeY) * 0.36, 0.0001));
    expect(board.state, 'swapSettle');
    expect(
      board.stageTimer,
      closeTo(MatchBoardLogic.swapSettleDelay - 0.02, 0.0001),
    );
  });
}
