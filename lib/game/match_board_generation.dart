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
    if (resetStats) {
      stats = MatchBoardGameStats();
    }
    _fillBoardWithRandomValidLayout();
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
    final ordinaryColors = <int>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final gem = getGem(r, c);
        if (gem == null || gem.kind != GemKind.normal) continue;
        ordinaryCells.add(Point(r, c));
        ordinaryColors.add(gem.color);
      }
    }
    if (ordinaryCells.length < 2) return false;

    final originalColors = <int>[...ordinaryColors];
    for (var attempt = 0; attempt < 80; attempt++) {
      ordinaryColors.shuffle(_random);
      for (var i = 0; i < ordinaryCells.length; i++) {
        final cell = ordinaryCells[i];
        getGem(cell.x, cell.y)?.color = ordinaryColors[i];
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
      getGem(cell.x, cell.y)?.color = originalColors[i];
    }
    return false;
  }
}
