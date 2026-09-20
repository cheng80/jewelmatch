import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stonematch/game/item_kind.dart';
import 'package:stonematch/game/match_board_game.dart';
import 'package:stonematch/game/match_board_logic.dart';
import 'package:stonematch/game/match_board_qa_bridge.dart';
import 'package:stonematch/services/game_settings.dart';
import 'package:stonematch/utils/storage_helper.dart';

void fill(MatchBoardLogic b, {bool validMove = false}) {
  b.setGeometry(x: 0, y: 0, tile: 56);
  for (var r = 0; r < 8; r++) {
    for (var c = 0; c < 8; c++) {
      b.setGem(r, c, b.createGem(r, c, (r + c) % 6 + 1, GemKind.normal));
    }
  }
  if (validMove) {
    for (final p in [(6, 0, 2), (7, 0, 5), (7, 1, 2), (7, 2, 2), (7, 3, 4)]) {
      b.getGem(p.$1, p.$2)!.color = p.$3;
    }
  }
  b.introFillInProgress = false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageHelper.init();
    GameSettings.sfxMuted = true;
    GameSettings.bgmMuted = true;
  });

  test('R1 swapSettle must reject swipe feedback through game surface', () {
    final g = MatchBoardGame();
    fill(g.board, validMove: true);
    expect(g.board.trySwap(6, 0, 7, 0), isTrue);
    final gem = g.board.getGem(7, 0)!;
    final origin = g.board.cellToPixel(7, 0);
    final accepted = g.handleBoardSwipe(
      origin.dx + 8,
      origin.dy + 8,
      origin.dx + 28,
      origin.dy + 8,
      0,
      1,
    );
    final draggingDuringSettle = g.board.hasInvalidDragFeedback;
    final offsetBefore = gem.x - gem.targetX;
    g.board.update(0.12);
    final movesDuringRemoval = g.updateInvalidBoardDrag(
      origin.dx + 40,
      origin.dy + 8,
    );
    expect(accepted, isFalse);
    expect(offsetBefore, 0);
    expect(g.board.state, 'removing');
    expect(movesDuringRemoval, isFalse);
    expect(gem.x, gem.targetX);
    expect(draggingDuringSettle, isFalse);
  });

  test('R2 invalid swipe must stay settled after drag return', () {
    final g = MatchBoardGame();
    fill(g.board);
    final gem = g.board.getGem(0, 0)!;
    expect(g.handleBoardSwipe(8, 8, 28, 8, 0, 1), isFalse);
    for (var i = 0; i < 30; i++) {
      g.board.update(1 / 60);
    }
    final heldTimer = gem.bumpT;
    g.endBoardDrag();
    g.board.update(MatchBoardLogic.invalidDragReturnDuration);
    expect(gem.x, gem.targetX);
    g.board.update(0.09);
    expect(heldTimer, lessThan(0));
    expect(gem.bumpT, lessThan(0));
    expect(gem.x, closeTo(gem.targetX, 0.001));
  });

  test('R3 resized bump must use current tile dimensions', () {
    final b = MatchBoardLogic(rows: 8, cols: 8);
    fill(b);
    expect(b.trySwap(0, 0, 0, 1), isFalse);
    b.update(0.05);
    b.setGeometry(x: 10, y: 20, tile: 28);
    final gem = b.getGem(0, 0)!;
    expect(gem.x, gem.targetX);
    b.update(0.04);
    expect(gem.bumpX, 0);
    expect(gem.bumpT, lessThan(0));
    expect(gem.x - gem.targetX, lessThanOrEqualTo(b.tileSize * 0.3));
  });

  test(
    'settle blocks logic taps, all board items, special taps and game items',
    () {
      final g = MatchBoardGame();
      fill(g.board, validMove: true);
      g.board.getGem(0, 0)!.kind = GemKind.bomb;
      expect(g.board.trySwap(6, 0, 7, 0), isTrue);
      expect(g.board.triggerSpecialCell(0, 0), isFalse);
      for (final item in ItemKind.values) {
        expect(
          g.board.useBoardItem(item, row: 0, col: 1, prismColor: 1),
          isFalse,
          reason: item.name,
        );
        expect(g.useTestItem(item), isFalse, reason: item.name);
      }
      g.handleBoardTap(30, 30);
      expect(g.board.selected, isNull);
      expect(g.board.state, 'swapSettle');
      expect(g.board.score, 0);
    },
  );

  test('special taps and prism remain direct removing paths', () {
    for (final kind in GemKind.values.where((k) => k != GemKind.normal)) {
      final b = MatchBoardLogic(rows: 8, cols: 8);
      fill(b);
      b.getGem(3, 3)!.kind = kind;
      expect(b.triggerSpecialCell(3, 3), isTrue, reason: kind.name);
      expect(b.state, 'removing', reason: kind.name);
    }
    final b = MatchBoardLogic(rows: 8, cols: 8);
    fill(b, validMove: true);
    expect(
      b.useBoardItem(ItemKind.prismTransform, row: 7, col: 0, prismColor: 2),
      isTrue,
    );
    expect(b.state, 'removing');
  });

  test('stable states and QA simulation retain swapSettle transition', () {
    for (final state in ['idle', 'falling', 'refilling', 'checking']) {
      final b = MatchBoardLogic(rows: 8, cols: 8);
      fill(b, validMove: true);
      b.state = state;
      b.stageTimer = 1;
      expect(b.trySwap(6, 0, 7, 0), isTrue, reason: state);
      expect(b.state, 'swapSettle');
      b.update(0.121);
      expect(b.state, 'removing');
      b.update(0.181);
      expect(b.score, 100);
    }
    final g = MatchBoardGame();
    fill(g.board, validMove: true);
    expect(g.performSimulationHintMove(), isTrue);
    expect(g.board.state, 'swapSettle');
    expect(g.performSimulationHintMove(), isFalse);
  });
}
