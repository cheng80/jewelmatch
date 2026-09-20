part of 'match_board_logic.dart';

extension MatchBoardInput on MatchBoardLogic {
  bool _triggerSpecialSwapImpl(int ar, int ac, int br, int bc) {
    // 특수 보석은 스왑 콤보가 아니라 해당 보석 탭으로만 발동한다.
    return false;
  }

  bool _triggerSpecialCellImpl(int row, int col) {
    clearHint();
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
      // 무효 스왑 범프: 서로 쪽으로 밀렸다가 기존 트윈으로 제자리에 돌아온다.
      final bumpX = (gemB.targetX - gemA.targetX) * 0.3;
      final bumpY = (gemB.targetY - gemA.targetY) * 0.3;
      gemA
        ..bumpT = 0
        ..bumpX = bumpX
        ..bumpY = bumpY;
      gemB
        ..bumpT = 0
        ..bumpX = -bumpX
        ..bumpY = -bumpY;
      lastActionText = 'bad swap';
      lockInput(MatchBoardLogic.invalidSwapLock);
      onInvalidSwap?.call();
      return false;
    }

    // 복귀 트윈이 새 스왑의 좌표를 덮지 않도록 같은 보석만 취소한다.
    if (identical(_invalidDragReturnGem, gemA) ||
        identical(_invalidDragReturnGem, gemB)) {
      _invalidDragReturnGem = null;
      _invalidDragReturnElapsed = 0;
    }
    if (identical(_invalidDragGem, gemA) || identical(_invalidDragGem, gemB)) {
      _invalidDragGem = null;
    }
    gemA.bumpT = -1;
    gemB.bumpT = -1;
    pendingMoveInfo = MoveInfo(movedA: Point(br, bc), movedB: Point(ar, ac));
    pendingRemovalSet = null;
    state = 'swapSettle';
    stageTimer = MatchBoardLogic.swapSettleDelay;
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
    idleHintElapsed = 0;
    _automaticHintVisible = false;
    swapPreviewCell = null;
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
    clearHint();
    if (!isInside(row, col)) {
      selected = null;
      return;
    }
    final changed = selected?.x != row || selected?.y != col;
    selected = Point(row, col);
    if (changed && getGem(row, col) != null) onGemSelected?.call();
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
    // trySwap의 false는 무효 매치뿐 아니라 상태/안정구역 거절도 포함한다.
    // 안착/제거 중 거절된 입력을 시각 드래그로 다시 받아들이지 않는다.
    if (introFillInProgress || !_canSelectCellNow(row, col)) return;
    clearHint();
    final gem = getGem(row, col);
    if (gem == null) return;
    gem.bumpT = -1;
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
    if ((state != 'idle' && !_allowsStableZoneSwapState) ||
        !identical(getGem(gem.row, gem.col), gem) ||
        isPendingRemovalCell(gem.row, gem.col)) {
      endInvalidDragFeedback();
      return false;
    }
    if (!isPixelInsideBoard(px, py)) {
      endInvalidDragFeedback();
      return false;
    }
    idleHintElapsed = 0;
    final dx = px + _invalidDragOffsetX - gem.targetX;
    final dy = py + _invalidDragOffsetY - gem.targetY;
    final r = gem.row + (dy.abs() > dx.abs() ? dy.sign.toInt() : 0);
    final c = gem.col + (dx.abs() >= dy.abs() ? dx.sign.toInt() : 0);
    if (isInside(r, c) && areAdjacent(gem.row, gem.col, r, c)) {
      if (swapPreviewCell?.x != r || swapPreviewCell?.y != c) {
        swapPreviewCell = Point(r, c);
      }
    } else {
      swapPreviewCell = null;
    }
    gem.x = px + _invalidDragOffsetX;
    gem.y = py + _invalidDragOffsetY;
    return true;
  }

  void _endInvalidDragFeedbackImpl() {
    swapPreviewCell = null;
    idleHintElapsed = 0;
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
    swapPreviewCell = null;
    idleHintElapsed = 0;
    _invalidDragGem = null;
    _invalidDragOffsetX = 0;
    _invalidDragOffsetY = 0;
    _invalidDragReturnGem = null;
    _invalidDragReturnStartX = 0;
    _invalidDragReturnStartY = 0;
    _invalidDragReturnElapsed = 0;
  }
}
