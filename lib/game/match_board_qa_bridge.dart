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

  bool performSimulationHintMove() {
    final move = readSimulationHintMove();
    if (move == null) return false;
    final a = move['a'] as Map<String, Object?>;
    final b = move['b'] as Map<String, Object?>;
    final swapsBefore = board.stats.validSwaps;
    handleBoardTap(a['x'] as double, a['y'] as double);
    handleBoardTap(b['x'] as double, b['y'] as double);
    return board.stats.validSwaps > swapsBefore;
  }

  /// 스왑해도 매치가 생기지 않는 이웃 두 칸. 눈검증의 무효 스왑 범프 확인용.
  SimulationHintMove? readSimulationInvalidMove() {
    if (!isPlaying ||
        timeUp ||
        board.inputLocked ||
        board.introFillInProgress ||
        board.state != 'idle') {
      return null;
    }
    final valid = board.getAllValidMoves();
    bool isValidPair(int ar, int ac, int br, int bc) {
      for (final move in valid) {
        if (move.a.x == ar &&
            move.a.y == ac &&
            move.b.x == br &&
            move.b.y == bc) {
          return true;
        }
        if (move.a.x == br &&
            move.a.y == bc &&
            move.b.x == ar &&
            move.b.y == ac) {
          return true;
        }
      }
      return false;
    }

    for (var row = 0; row < MatchBoardGame.rows; row++) {
      for (var col = 0; col < MatchBoardGame.cols; col++) {
        for (final dir in const [
          [0, 1],
          [1, 0],
        ]) {
          final or = row + dir[0];
          final oc = col + dir[1];
          if (!board.isInside(or, oc)) continue;
          if (board.getGem(row, col) == null) continue;
          if (board.getGem(or, oc) == null) continue;
          if (isValidPair(row, col, or, oc)) continue;

          final aTopLeft = board.cellToPixel(row, col);
          final bTopLeft = board.cellToPixel(or, oc);
          final halfTile = board.tileSize / 2;
          return {
            'a': {
              'row': row,
              'col': col,
              'x': aTopLeft.dx + halfTile,
              'y': aTopLeft.dy + halfTile,
            },
            'b': {
              'row': or,
              'col': oc,
              'x': bTopLeft.dx + halfTile,
              'y': bTopLeft.dy + halfTile,
            },
            'tileSize': board.tileSize,
            'state': board.state,
          };
        }
      }
    }
    return null;
  }

  bool performSimulationInvalidMove() {
    final move = readSimulationInvalidMove();
    if (move == null) return false;
    final a = move['a'] as Map<String, Object?>;
    final b = move['b'] as Map<String, Object?>;
    handleBoardTap(a['x'] as double, a['y'] as double);
    handleBoardTap(b['x'] as double, b['y'] as double);
    return true;
  }
}

typedef SimulationGameState = Map<String, Object?>;

extension MatchBoardSimulationState on MatchBoardGame {
  Map<String, Object?>? _readChallengeState() {
    final challenge = stageChallenge;
    if (challenge == null) return null;
    return {
      'kind': challenge.kind.name,
      'target': challenge.target,
      'progress': challenge.progress(board.stats),
      'color': challenge.color,
    };
  }

  SimulationGameState readSimulationState() {
    return {
      'mode': gameMode.queryParam,
      'score': board.score,
      'level': progressionLevel,
      'targetScore': progressionTargetScore,
      'challenge': _readChallengeState(),
      'levelUpActive': overlays.isActive('LevelUp'),
      'stageInventoryActive': overlays.isActive('StageInventory'),
      'levelCelebrationActive': overlays.isActive('LevelCelebration'),
      'timeUp': timeUp,
      'lastHurrahActive': lastHurrahActive,
      'timeRemaining': timeRemaining,
      'remainingHints': remainingHints,
      'hasLimitedHints': hasLimitedHints,
      'hasTimedClock': hasTimedClock,
      'runInventory': {
        for (final entry in runInventory.snapshot().entries)
          entry.key.name: entry.value,
      },
      'stageLoadout': [
        for (final slot in stageLoadout.slots)
          {
            'index': slot.index,
            'item': slot.item?.name,
            'locked': slot.locked,
            'open': slot.open,
          },
      ],
      'latestStageRewards': [
        for (final reward in latestStageRewards)
          {
            'item': reward.item.name,
            'quantity': reward.quantity,
            'reasonKey': reward.reasonKey,
          },
      ],
      'stageRewardClaimKey': stageRewardClaimKey,
      'stageLoadoutOpenSlotCount': stageLoadoutOpenSlotCount,
      'recentlyUnlockedLoadoutSlotIndices': recentlyUnlockedLoadoutSlotIndices,
      'isPlaying': isPlaying,
      'boardState': board.state,
      'boardGeometry': {
        'x': board.boardX,
        'y': board.boardY,
        'tileSize': board.tileSize,
        'rows': MatchBoardGame.rows,
        'cols': MatchBoardGame.cols,
      },
      'boardShakeOffset': {'x': boardShakeOffset.x, 'y': boardShakeOffset.y},
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
