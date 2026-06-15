part of 'match_game_hud.dart';

extension _MatchGameHudInteractions on MatchGameHud {
  void _updateHudState() {
    final currentHudTextScale = game.hudTextScale;
    if (_cachedHudTextScale != currentHudTextScale) {
      _layout();
      return;
    }

    if (_cachedScore != game.board.score) {
      _rebuildScoreValue();
    }

    final latestBest = GameSettings.getBestMatchScore(game.gameMode);
    final latestBestProgressionLevel =
        GameSettings.getBestMatchProgressionLevel();
    if (latestBest != _cachedBest ||
        latestBestProgressionLevel != _cachedBestProgressionLevel) {
      _cachedBest = latestBest;
      _cachedBestProgressionLevel = latestBestProgressionLevel;
      _rebuildStaticPainters();
      return;
    }

    if (_cachedRankingTop1Name != game.rankingTop1Name ||
        _cachedRankingTop1Score != game.rankingTop1Score) {
      _rebuildStaticPainters();
      return;
    }

    final timedModeChanged = _cachedTimedModeForText != game.hasTimedClock;
    final currentTimedSeconds = game.hasTimedClock
        ? game.timeRemaining.ceil().clamp(0, 99999)
        : null;
    final currentProgressionXp = game.isProgressionMode
        ? game.progressionLevel
        : null;
    if (timedModeChanged ||
        _cachedTimedSeconds != currentTimedSeconds ||
        _cachedProgressionXp != currentProgressionXp) {
      _rebuildTimeBarText();
    }

    final displayedCombo = _displayCurrentCombo();
    final maxCombo = game.board.maxCombo;
    if (_cachedDisplayedCombo != displayedCombo ||
        _cachedMaxCombo != maxCombo) {
      _rebuildComboPainters();
    }
  }

  void _renderHud(Canvas canvas) {
    final g = game;
    if (!g.hasLayout || g.size.x <= 0 || g.size.y <= 0) return;

    _renderBestBlock(canvas);
    _drawTutorialButton(canvas);
    _renderScoreBlock(canvas);
    _renderComboStrip(canvas);
    _renderTimeBar(canvas);
    _drawHintButton(canvas);
    if (onRankingPressed != null && _rankingRect.width > 0) {
      _drawRankingButton(canvas);
    }
    _drawPause(canvas);
  }

  void _handleTapDown(TapDownEvent event) {
    final p = event.localPosition;
    if (_handleUiButtonTap(p)) return;
    final bt = game.board.boardY;
    final bb = game.boardPixelBottom;
    if (p.y < bt || p.y > bb) {
      game.dismissHint();
      return;
    }
    game.handleBoardTap(event.canvasPosition.x, event.canvasPosition.y);
  }

  void _handleDragStart(DragStartEvent event) {
    _resetDrag();
    final p = event.localPosition;
    if (_isUiButton(p)) return;
    final bt = game.board.boardY;
    final bb = game.boardPixelBottom;
    if (p.y < bt || p.y > bb) return;
    _drag.start(event.canvasPosition);
  }

  void _handleDragUpdate(DragUpdateEvent event) {
    final swipe = _drag.consumeSwipe(
      event.localDelta,
      MatchGameHud._swipeThreshold,
    );
    if (swipe == null) return;
    game.handleBoardSwipe(swipe.start.x, swipe.start.y, swipe.dr, swipe.dc);
  }

  void _handleDragEnd() {
    final fallbackTap = _drag.fallbackTap;
    if (fallbackTap != null) {
      game.handleBoardTap(fallbackTap.x, fallbackTap.y);
    }
    _resetDrag();
  }

  void _resetDrag() {
    _drag.reset();
  }

  bool _isUiButton(Vector2 p) {
    final o = Offset(p.x, p.y);
    return _pauseRect.contains(o) ||
        _hintRect.contains(o) ||
        (onRankingPressed != null &&
            _rankingRect.width > 0 &&
            _rankingRect.contains(o)) ||
        _tutorialRect.contains(o);
  }

  bool _handleUiButtonTap(Vector2 p) {
    final o = Offset(p.x, p.y);
    if (_pauseRect.contains(o)) {
      game.dismissHint();
      onPausePressed();
      return true;
    }
    if (_hintRect.contains(o)) {
      onHintPressed();
      return true;
    }
    if (onRankingPressed != null &&
        _rankingRect.width > 0 &&
        _rankingRect.contains(o)) {
      game.dismissHint();
      onRankingPressed!();
      return true;
    }
    if (_tutorialRect.contains(o)) {
      game.dismissHint();
      onTutorialPressed();
      return true;
    }
    return false;
  }
}
