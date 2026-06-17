import 'match_board_game.dart';

export 'match_board_qa_bridge_stub.dart'
    if (dart.library.js_interop) 'match_board_qa_bridge_web.dart';

typedef SimulationHintMove = Map<String, Object?>;

extension MatchBoardSimulationHints on MatchBoardGame {
  SimulationHintMove? readSimulationHintMove() {
    if (!isPlaying ||
        timeUp ||
        board.inputLocked ||
        board.introFillInProgress) {
      return null;
    }
    if (board.hintCellA == null || board.hintCellB == null) {
      if (!board.showHint()) return null;
    }

    final a = board.hintCellA;
    final b = board.hintCellB;
    if (a == null || b == null) return null;

    final aTopLeft = board.cellToPixel(a.x, a.y);
    final bTopLeft = board.cellToPixel(b.x, b.y);
    final halfTile = board.tileSize / 2;

    return {
      'a': {
        'row': a.x,
        'col': a.y,
        'x': aTopLeft.dx + halfTile,
        'y': aTopLeft.dy + halfTile,
      },
      'b': {
        'row': b.x,
        'col': b.y,
        'x': bTopLeft.dx + halfTile,
        'y': bTopLeft.dy + halfTile,
      },
      'tileSize': board.tileSize,
      'state': board.state,
    };
  }
}

typedef SimulationGameState = Map<String, Object?>;

extension MatchBoardSimulationState on MatchBoardGame {
  SimulationGameState readSimulationState() {
    return {
      'mode': gameMode.queryParam,
      'score': board.score,
      'level': progressionLevel,
      'targetScore': progressionTargetScore,
      'levelUpActive': overlays.isActive('LevelUp'),
      'levelCelebrationActive': overlays.isActive('LevelCelebration'),
      'timeUp': timeUp,
      'timeRemaining': timeRemaining,
      'remainingHints': remainingHints,
      'hasLimitedHints': hasLimitedHints,
      'hasTimedClock': hasTimedClock,
      'isPlaying': isPlaying,
      'boardState': board.state,
      'boardGeometry': {
        'x': board.boardX,
        'y': board.boardY,
        'tileSize': board.tileSize,
        'rows': MatchBoardGame.rows,
        'cols': MatchBoardGame.cols,
      },
      'alignedHudRects': {
        for (final entry in debugReadAlignedHudRects().entries)
          entry.key: {
            'left': entry.value.left,
            'top': entry.value.top,
            'right': entry.value.right,
            'bottom': entry.value.bottom,
            'width': entry.value.width,
            'height': entry.value.height,
          },
      },
      'itemSlotRects': {
        for (final entry in debugReadItemSlotRects().entries)
          entry.key.name: {
            'left': entry.value.left,
            'top': entry.value.top,
            'right': entry.value.right,
            'bottom': entry.value.bottom,
            'centerX': entry.value.center.dx,
            'centerY': entry.value.center.dy,
          },
      },
      'isItemTargeting': isItemTargeting,
      'activeTargetItem': activeTargetItem?.name,
      'selectedPrismColor': selectedPrismColor,
      'pendingImmediateItemConfirm': pendingImmediateItemConfirm?.name,
      'prismColorRects': {
        for (final entry in debugReadPrismColorRects().entries)
          '${entry.key}': {
            'left': entry.value.left,
            'top': entry.value.top,
            'right': entry.value.right,
            'bottom': entry.value.bottom,
            'centerX': entry.value.center.dx,
            'centerY': entry.value.center.dy,
          },
      },
      'itemFeedbackText': itemFeedbackText,
      'itemFeedbackOpacity': itemFeedbackOpacity,
      'hasActiveVisualEffects': hasActiveVisualEffects,
      'introFillInProgress': board.introFillInProgress,
    };
  }
}
