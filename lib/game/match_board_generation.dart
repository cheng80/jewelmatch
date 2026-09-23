part of 'match_board_logic.dart';

extension MatchBoardGeneration on MatchBoardLogic {
  bool _causesImmediateMatchImpl(int row, int col, int color) {
    final l1 = getGem(row, col - 1);
    final l2 = getGem(row, col - 2);
    if (l1 != null &&
        l2 != null &&
        gemMatchColor(l1) == color &&
        gemMatchColor(l2) == color) {
      return true;
    }
    final u1 = getGem(row - 1, col);
    final u2 = getGem(row - 2, col);
    if (u1 != null &&
        u2 != null &&
        gemMatchColor(u1) == color &&
        gemMatchColor(u2) == color) {
      return true;
    }
    return false;
  }

  int _randomAllowedColorImpl(int row, int col) {
    final allowed = <int>[];
    for (var color = 1; color <= colorCount; color++) {
      if (!causesImmediateMatch(row, col, color)) {
        allowed.add(color);
      }
    }
    if (allowed.isEmpty) {
      return _random.nextInt(colorCount) + 1;
    }
    return allowed[_random.nextInt(allowed.length)];
  }

  void _fillBoardWithRandomValidLayoutImpl() {
    var attempts = 0;
    do {
      attempts++;
      resetCells();
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          final color = randomAllowedColor(r, c);
          setGem(r, c, createGem(r, c, color, GemKind.normal));
        }
      }
    } while (hasMatches() || !hasAnyValidMove());

    selected = null;
    state = 'idle';
    lastActionText = attempts > 1 ? 'board regen x$attempts' : 'ready';
    clearHint();
    introFillInProgress = false;
    introFillPaused = false;
  }

  void _generateFreshBoardImpl({
    bool withIntroFill = true,
    BoardFillIntroKind introKind = BoardFillIntroKind.roundStart,
    bool resetStats = true,
  }) {
    // 판 도중 새 보드(NoMoves)는 속성 보석 수를 새 보드로 옮긴다. 새 판은 배율과 한 수 집계를 비운다.
    final carriedBonuses = <GemBonus>[];
    if (resetStats) {
      stats = MatchBoardGameStats();
      scoreMultiplier = 1;
      _swapMoveActive = false;
      _swapMoveRemoved = 0;
    } else {
      for (final row in cells) {
        for (final gem in row) {
          if (gem != null && gem.bonus != GemBonus.none) {
            carriedBonuses.add(gem.bonus);
          }
        }
      }
    }
    _plainThreeStep = false;
    _pendingTimeGems = 0;
    _pendingMultiplierGems = 0;
    _fillBoardWithRandomValidLayout();
    for (final bonus in carriedBonuses) {
      placeBonusGem(bonus, pop: false);
    }
    if (withIntroFill) {
      prepareIntroFill(kind: introKind);
    } else {
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          final g = cells[r][c];
          if (g != null) {
            g.x = g.targetX;
            g.y = g.targetY;
          }
        }
      }
    }
  }

  void _shuffleImpl() {
    generateFreshBoard(
      withIntroFill: true,
      introKind: BoardFillIntroKind.shuffleRefill,
      resetStats: false,
    );
    lastActionText = 'shuffled';
  }

  bool _shuffleOrdinaryGemsPreservingSpecialsImpl() {
    if (inputLocked || state != 'idle') return false;

    final ordinaryCells = <Point<int>>[];
    // 속성은 색과 함께 섞여 보석을 따라간다. 섞는 횟수와 난수 소비는 색만 섞을 때와 같다.
    final ordinaryGems = <(int, GemBonus)>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final gem = getGem(r, c);
        if (gem == null || gem.kind != GemKind.normal) continue;
        ordinaryCells.add(Point(r, c));
        ordinaryGems.add((gem.color, gem.bonus));
      }
    }
    if (ordinaryCells.length < 2) return false;

    final originalGems = <(int, GemBonus)>[...ordinaryGems];
    for (var attempt = 0; attempt < 80; attempt++) {
      ordinaryGems.shuffle(_random);
      for (var i = 0; i < ordinaryCells.length; i++) {
        final cell = ordinaryCells[i];
        getGem(cell.x, cell.y)
          ?..color = ordinaryGems[i].$1
          ..bonus = ordinaryGems[i].$2;
      }
      if (!hasMatches() && hasAnyValidMove()) {
        selected = null;
        clearHint();
        lastActionText = 'fate shuffle';
        lockInput(MatchBoardLogic.shuffleLock);
        return true;
      }
    }

    for (var i = 0; i < ordinaryCells.length; i++) {
      final cell = ordinaryCells[i];
      getGem(cell.x, cell.y)
        ?..color = originalGems[i].$1
        ..bonus = originalGems[i].$2;
    }
    return false;
  }
}
