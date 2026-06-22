part of 'match_board_logic.dart';

extension MatchBoardInput on MatchBoardLogic {
  bool _triggerSpecialSwapImpl(int ar, int ac, int br, int bc) {
    final gemA = getGem(ar, ac)!;
    final gemB = getGem(br, bc)!;
    final removalSet = <String, bool>{};
    final queue = <MatchChainItem>[];

    if (gemA.kind == GemKind.hyper && gemB.kind == GemKind.hyper) {
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          removalSet[_cellKey(r, c)] = true;
        }
      }
      resolveSpecialSwap(removalSet, queue, 'hyper x2');
      return true;
    }

    if (gemA.kind == GemKind.hyper || gemB.kind == GemKind.hyper) {
      late int hyperR, hyperC;
      late BoardGem other;
      if (gemA.kind == GemKind.hyper) {
        hyperR = ar;
        hyperC = ac;
        other = gemB;
      } else {
        hyperR = br;
        hyperC = bc;
        other = gemA;
      }
      removalSet[_cellKey(ar, ac)] = true;
      removalSet[_cellKey(br, bc)] = true;
      queue.add(
        MatchChainItem(
          row: hyperR,
          col: hyperC,
          kind: GemKind.hyper,
          triggerColor: other.kind == GemKind.hyper
              ? pickExistingColor()
              : other.color,
        ),
      );
      resolveSpecialSwap(removalSet, queue, 'hyper');
      return true;
    }

    final combo = buildNonHyperSpecialSwapCombo(
      a: gemA,
      b: gemB,
      getGem: getGem,
      rows: rows,
      cols: cols,
    );
    if (combo != null) {
      resolveSpecialSwap(combo.removalSet, combo.queue, combo.label);
      return true;
    }

    return false;
  }

  bool _trySwapImpl(int ar, int ac, int br, int bc) {
    clearHint();
    if (!_canTrySwapNow(ar, ac, br, bc)) return false;
    if (!isInside(ar, ac) || !isInside(br, bc)) return false;
    if (!areAdjacent(ar, ac, br, bc)) return false;

    final gemA = getGem(ar, ac);
    final gemB = getGem(br, bc);
    if (gemA == null || gemB == null) return false;

    if (triggerSpecialSwap(ar, ac, br, bc)) {
      stats.recordValidSwap();
      selected = null;
      return true;
    }

    swapCells(ar, ac, br, bc);

    final matchA = findMatchesAt(br, bc);
    final matchB = findMatchesAt(ar, ac);
    if (matchA.groups.isEmpty && matchB.groups.isEmpty) {
      swapCells(ar, ac, br, bc);
      lastActionText = 'bad swap';
      lockInput(MatchBoardLogic.invalidSwapLock);
      onInvalidSwap?.call();
      return false;
    }

    resolveMatchCascade(MoveInfo(movedA: Point(br, bc), movedB: Point(ar, ac)));
    stats.recordValidSwap();
    selected = null;
    return true;
  }

  bool _canTrySwapNow(int ar, int ac, int br, int bc) {
    if (inputLocked) return false;
    if (state == 'idle') return true;
    if (!_allowsStableZoneSwapState) return false;
    return _isStableSwapCell(ar, ac) && _isStableSwapCell(br, bc);
  }

  bool get _allowsStableZoneSwapState =>
      state == 'falling' || state == 'refilling' || state == 'checking';

  bool _canSelectCellNow(int row, int col) {
    if (state == 'idle') return true;
    if (!_allowsStableZoneSwapState) return false;
    return _isStableSwapCell(row, col);
  }

  bool _isStableSwapCell(int row, int col) {
    if (!isInside(row, col)) return false;
    if (pendingRemovalSet?.containsKey(_cellKey(row, col)) ?? false) {
      return false;
    }
    final gem = getGem(row, col);
    if (gem == null) return false;
    if (gem.row != row || gem.col != col) return false;
    if (!_isGemVisuallySettled(gem)) return false;
    return !_hasEmptyCellBelow(row, col);
  }

  bool _isGemVisuallySettled(BoardGem gem) {
    const epsilon = 0.45;
    return (gem.x - gem.targetX).abs() <= epsilon &&
        (gem.y - gem.targetY).abs() <= epsilon;
  }

  bool _hasEmptyCellBelow(int row, int col) {
    for (var r = row + 1; r < rows; r++) {
      if (getGem(r, col) == null) return true;
    }
    return false;
  }

  void _clearHintImpl() {
    _hintA = null;
    _hintB = null;
  }

  bool _showHintImpl() {
    if (state != 'idle' || inputLocked) return false;
    final moves = getAllValidMoves();
    if (moves.isEmpty) return false;
    final signature = _hintMoveSignature(moves);
    if (_hintMovesSignature != signature) {
      _hintMovesSignature = signature;
      _hintMoveIndex = 0;
      _shuffledHintMoves = List<ValidMovePair>.of(moves)..shuffle(_random);
    }
    final shuffledMoves = _shuffledHintMoves;
    final pick = shuffledMoves[_hintMoveIndex % shuffledMoves.length];
    _hintMoveIndex = (_hintMoveIndex + 1) % shuffledMoves.length;
    _hintA = pick.a;
    _hintB = pick.b;
    return true;
  }

  String _hintMoveSignature(List<ValidMovePair> moves) {
    final buffer = StringBuffer();
    for (final move in moves) {
      buffer
        ..write(move.a.x)
        ..write(':')
        ..write(move.a.y)
        ..write('>')
        ..write(move.b.x)
        ..write(':')
        ..write(move.b.y)
        ..write(';');
    }
    return buffer.toString();
  }

  List<ValidMovePair> _getAllValidMovesImpl() {
    final moves = <ValidMovePair>[];
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        for (final dir in const [
          [0, 1],
          [1, 0],
        ]) {
          final or = row + dir[0];
          final oc = col + dir[1];
          if (!isInside(or, oc)) continue;
          final gemA = getGem(row, col);
          final gemB = getGem(or, oc);
          if (gemA == null || gemB == null) continue;

          var isValid = false;
          final specialCombo = buildNonHyperSpecialSwapCombo(
            a: gemA,
            b: gemB,
            getGem: getGem,
            rows: rows,
            cols: cols,
          );
          if (gemA.kind == GemKind.hyper ||
              gemB.kind == GemKind.hyper ||
              specialCombo != null) {
            isValid = true;
          } else {
            swapCells(row, col, or, oc);
            final matchA = findMatchesAt(or, oc);
            final matchB = findMatchesAt(row, col);
            swapCells(row, col, or, oc);
            isValid = matchA.groups.isNotEmpty || matchB.groups.isNotEmpty;
          }

          if (isValid) {
            moves.add(ValidMovePair(a: Point(row, col), b: Point(or, oc)));
          }
        }
      }
    }
    return moves;
  }

  void _clearSelectionImpl() => selected = null;

  void _selectCellImpl(int row, int col) {
    if (!isInside(row, col)) {
      selected = null;
      return;
    }
    selected = Point(row, col);
  }

  void _handleTapImpl(double px, double py) {
    if (introFillInProgress) return;
    clearHint();
    if (inputLocked) return;
    final cell = pixelToCell(px, py);
    if (cell == null) {
      selected = null;
      return;
    }
    final row = cell.x;
    final col = cell.y;

    if (!_canSelectCellNow(row, col)) {
      selected = null;
      return;
    }

    if (selected == null) {
      selectCell(row, col);
      return;
    }
    if (selected!.x == row && selected!.y == col) {
      selected = null;
      return;
    }
    if (areAdjacent(selected!.x, selected!.y, row, col)) {
      final sr = selected!.x;
      final sc = selected!.y;
      selected = null;
      trySwap(sr, sc, row, col);
      return;
    }
    selectCell(row, col);
  }

  void _startInvalidDragFeedbackImpl({
    required int row,
    required int col,
    required double startX,
    required double startY,
    required double currentX,
    required double currentY,
  }) {
    final gem = getGem(row, col);
    if (gem == null) return;
    _invalidDragReturnGem = null;
    _invalidDragReturnElapsed = 0;
    _invalidDragGem = gem;
    _invalidDragOffsetX = gem.targetX - startX;
    _invalidDragOffsetY = gem.targetY - startY;
    updateInvalidDragFeedback(currentX, currentY);
  }

  bool _updateInvalidDragFeedbackImpl(double px, double py) {
    final gem = _invalidDragGem;
    if (gem == null) return false;
    if (!isPixelInsideBoard(px, py)) {
      endInvalidDragFeedback();
      return false;
    }
    gem.x = px + _invalidDragOffsetX;
    gem.y = py + _invalidDragOffsetY;
    return true;
  }

  void _endInvalidDragFeedbackImpl() {
    final gem = _invalidDragGem;
    if (gem != null) {
      _invalidDragReturnGem = gem;
      _invalidDragReturnStartX = gem.x;
      _invalidDragReturnStartY = gem.y;
      _invalidDragReturnElapsed = 0;
    }
    _invalidDragGem = null;
    _invalidDragOffsetX = 0;
    _invalidDragOffsetY = 0;
  }

  void _clearInvalidDragFeedback() {
    _invalidDragGem = null;
    _invalidDragOffsetX = 0;
    _invalidDragOffsetY = 0;
    _invalidDragReturnGem = null;
    _invalidDragReturnStartX = 0;
    _invalidDragReturnStartY = 0;
    _invalidDragReturnElapsed = 0;
  }
}
