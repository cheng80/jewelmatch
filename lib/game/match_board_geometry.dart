part of 'match_board_logic.dart';

extension MatchBoardGeometry on MatchBoardLogic {
  void _setGeometryImpl({
    required double x,
    required double y,
    required double tile,
  }) {
    boardX = x;
    boardY = y;
    tileSize = tile;
    if (cells.length != rows || cells.any((row) => row.length != cols)) {
      return;
    }
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final g = cells[r][c];
        if (g != null) {
          _updateGemTarget(g);
          if (state == 'idle' && !introFillInProgress) {
            g.x = g.targetX;
            g.y = g.targetY;
          }
        }
      }
    }
    if (introFillInProgress) {
      _syncIntroPositionsAfterGeometry();
    }
  }

  double get _introFallDyImpl => (rows + 4) * tileSize;

  double _introHoldYAboveImpl(BoardGem gem) => gem.targetY - _introFallDy;

  int get _introActiveRowImpl => rows - 1 - _introWaveIndex;

  void _syncIntroPositionsAfterGeometryImpl() {
    if (!introFillInProgress) return;
    final activeRow = _introActiveRow;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final gem = cells[r][c];
        if (gem == null) continue;
        gem.x = gem.targetX;
        if (r > activeRow) {
          gem.y = gem.targetY;
        } else if (r < activeRow) {
          gem.y = _introHoldYAbove(gem);
        } else {
          gem.y = gem.targetY;
        }
      }
    }
  }

  void _prepareIntroFillImpl({
    BoardFillIntroKind kind = BoardFillIntroKind.roundStart,
  }) {
    _pendingIntroKind = kind;
    _introWaveIndex = 0;
    introFillInProgress = true;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final gem = cells[r][c];
        if (gem == null) continue;
        gem.x = gem.targetX;
        gem.y = _introHoldYAbove(gem);
      }
    }
  }

  void _updateGemTargetImpl(BoardGem gem) {
    final p = cellToPixel(gem.row, gem.col);
    gem.targetX = p.dx;
    gem.targetY = p.dy;
  }

  Offset _cellToPixelImpl(int row, int col) {
    return Offset(boardX + col * tileSize, boardY + row * tileSize);
  }

  Point<int>? _pixelToCellImpl(double px, double py) {
    if (px < boardX || py < boardY) return null;
    final lx = px - boardX;
    final ly = py - boardY;
    final col = (lx / tileSize).floor();
    final row = (ly / tileSize).floor();
    if (!isInside(row, col)) return null;
    return Point(row, col);
  }

  BoardGem _createGemImpl(
    int row,
    int col,
    int color,
    GemKind kind, {
    int spawnOffsetRows = 0,
  }) {
    final t = cellToPixel(row, col);
    var gy = t.dy;
    if (spawnOffsetRows > 0) {
      gy = t.dy - spawnOffsetRows * tileSize;
    }
    return _acquireGem(
      id: _nextId(),
      color: color,
      kind: kind,
      row: row,
      col: col,
      x: t.dx,
      y: gy,
      targetX: t.dx,
      targetY: t.dy,
    );
  }
}
