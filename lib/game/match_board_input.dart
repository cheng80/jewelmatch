part of 'match_board_logic.dart';

extension MatchBoardInput on MatchBoardLogic {
  bool _triggerSpecialSwapImpl(int ar, int ac, int br, int bc) {
    // 특수 보석은 스왑 콤보가 아니라 해당 보석 탭으로만 발동한다.
    return false;
  }

  bool _triggerSpecialCellImpl(int row, int col) {
    if (inputLocked || !isInside(row, col)) return false;
    if (!_canSelectCellNow(row, col)) return false;
    final gem = getGem(row, col);
    if (gem == null || !isSpecialGemKind(gem.kind)) return false;

    final removalSet = <String, bool>{_cellKey(row, col): true};
    final queue = <MatchChainItem>[
      MatchChainItem(
        row: row,
        col: col,
        kind: gem.kind,
        triggerColor: gem.kind == GemKind.hyper ? null : gem.color,
      ),
    ];
    selected = null;
    resolveSpecialSwap(removalSet, queue, _specialTapLabel(gem.kind));
    return true;
  }

  String _specialTapLabel(GemKind kind) {
    return switch (kind) {
      GemKind.bomb => 'bomb',
      GemKind.star => 'star',
      GemKind.hyper => 'hyper',
      GemKind.supernova => 'supernova',
      GemKind.row => 'row',
      GemKind.col => 'col',
      GemKind.normal => 'special',
    };
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

          swapCells(row, col, or, oc);
          final matchA = findMatchesAt(or, oc);
          final matchB = findMatchesAt(row, col);
          swapCells(row, col, or, oc);
          final isValid = matchA.groups.isNotEmpty || matchB.groups.isNotEmpty;

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

    final gem = getGem(row, col);
    if (gem != null && isSpecialGemKind(gem.kind)) {
      triggerSpecialCell(row, col);
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
