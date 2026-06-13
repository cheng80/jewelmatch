part of 'match_board_game.dart';

extension MatchBoardGameLayout on MatchBoardGame {
  double get _hudScaleImpl =>
      (size.x < size.y ? size.x : size.y) * MatchBoardGame._hudScaleRatio;

  double get _hudTextScaleImpl =>
      (hudScale / MatchBoardGame._hudLayoutRef).clamp(0.68, 1.42);

  double get _panelCenterYImpl => safeAreaPadding.top + hudScale * 0.62;

  double get _safeContentLeftImpl => safeAreaPadding.left + size.x * 0.03;

  double get _safeContentRightImpl =>
      size.x - safeAreaPadding.right - size.x * 0.03;

  double get _safeContentWidthImpl =>
      (safeContentRight - safeContentLeft).clamp(0.0, double.infinity);

  double get _safeContentCenterXImpl => safeContentLeft + safeContentWidth / 2;

  double get _gridTopYImpl => topChromeHeight;

  double get _layoutRefImpl {
    final availW = safeContentWidth;
    final maxGridH =
        (size.y - safeAreaPadding.bottom - gridTopY - bottomChromeHeight - 12)
            .clamp(0.0, double.infinity);
    return availW < maxGridH ? availW : maxGridH;
  }

  double get _boardPixelBottomImpl {
    final t = board.tileSize;
    if (t <= 0) return gridTopY;
    return board.boardY + MatchBoardGame.rows * t;
  }

  void _syncIntroInputBlockImpl() {
    if (board.introFillInProgress) {
      if (!overlays.isActive('IntroBlock')) {
        overlays.add('IntroBlock');
      }
    } else {
      overlays.remove('IntroBlock');
    }
  }

  void _syncLayoutImpl() {
    if (!hasLayout || size.x <= 0 || size.y <= 0) return;

    final ref = layoutRef;
    if (ref <= 0 || !ref.isFinite) return;

    const spacingRatio = 0.06;
    final denom =
        MatchBoardGame.cols + spacingRatio * (MatchBoardGame.cols + 1);
    final tile = ref / denom;
    if (tile <= 0 || !tile.isFinite) return;

    final spacing = tile * spacingRatio;
    final gridW =
        MatchBoardGame.cols * tile + (MatchBoardGame.cols + 1) * spacing;
    final left = safeContentLeft + (safeContentWidth - gridW) / 2 + spacing;
    final top = gridTopY + spacing;

    board.setGeometry(x: left, y: top, tile: tile);

    if (!_boardSeededFromLayout) {
      board.generateFreshBoard();
      _boardSeededFromLayout = true;
    } else if (board.state == 'idle' && !board.introFillInProgress) {
      for (var r = 0; r < MatchBoardGame.rows; r++) {
        for (var c = 0; c < MatchBoardGame.cols; c++) {
          final g = board.getGem(r, c);
          if (g != null) {
            g.x = g.targetX;
            g.y = g.targetY;
          }
        }
      }
    }
    _syncIntroInputBlock();
  }
}
