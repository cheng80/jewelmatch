part of 'match_game_hud.dart';

extension _MatchGameHudInteractions on MatchGameHud {
  void _updateHudState(double dt) {
    final currentHudTextScale = game.hudTextScale;
    if (_cachedHudTextScale != currentHudTextScale) {
      _layout();
      return;
    }

    // 새 라운드와 다음 레벨은 이전 연출을 이어받지 않는다.
    if (!identical(_feedbackBoard, game.board.stats) ||
        _feedbackLevel != game.progressionLevel) {
      _feedbackBoard = game.board.stats;
      _feedbackLevel = game.progressionLevel;
      _goalNear = false;
      _goalReached = false;
      _goalPunch.value = 0;
      _timeBonusPunch.value = 0;
      _itemUsePunch.value = 0;
      _hintBadgePunch.value = 0;
      _timeFillRatio = null;
      _lastTimeRatio = null;
      _lastHintCount = game.hintBadgeCount;
      _itemQuantities.fillRange(0, _itemQuantities.length, -1);
      _rebuildScoreValue();
    }
    _hudClock += dt;
    if (_hudClock > 1000) _hudClock -= 1000;
    _scorePunch.tick(dt);
    _comboPunch.tick(dt);
    _goalPunch.tick(dt);
    _hintBadgePunch.tick(dt);
    _timeBonusPunch.tick(dt);
    if (!(_pressTicker?.isActive ?? false)) _pressPunch.tick(dt);
    _itemUsePunch.tick(dt);
    if (!_pressPunch.isActive) _pressedRect = null;
    _rollScoreTowardTarget(dt);
    _updateGoalHighlight();
    _updateTimeFill(dt);
    _updateComboHeat(dt);
    final hintCount = game.hintBadgeCount;
    if (_lastHintCount != null &&
        hintCount != null &&
        _lastHintCount != hintCount) {
      _hintBadgePunch.trigger();
    }
    _lastHintCount = hintCount;
    _updateItemUseFeedback();

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

  /// 점수가 오르면 약 0.05초 간격으로 굴려 올린다. 줄어들면(재시작) 바로 맞춘다.
  void _rollScoreTowardTarget(double dt) {
    final target = game.board.score;
    final shown = _cachedScore;
    if (shown == target) return;
    if (shown == null || target < shown) {
      _scoreRollTarget = target;
      _rebuildScoreValue();
      return;
    }
    if (_scoreRollTarget != target) {
      _scoreRollTarget = target;
      _scorePunch.trigger();
    }
    _scoreRollTimer -= dt;
    if (_scoreRollTimer > 0) return;
    _scoreRollTimer = 0.045;
    final remaining = target - shown;
    final step = math.min(remaining, math.max(7, (remaining * 0.28).ceil()));
    _rebuildScoreValue(shown + step);
  }

  /// 레벨 모드: 목표의 80% 이상이면 은근히 맥동하고, 넘어서는 순간 한 번 강조한다.
  void _updateGoalHighlight() {
    if (!game.isProgressionMode) {
      _goalNear = false;
      _goalReached = false;
      return;
    }
    final challenge = game.stageChallenge;
    final double ratio;
    if (challenge != null) {
      final progress = challenge.progress(game.board.stats);
      if (progress != _challengeProgress ||
          challenge.kind != _challenge?.kind ||
          challenge.target != _challenge?.target) {
        _rebuildScoreValue(_cachedScore);
      }
      ratio = progress / challenge.target;
    } else {
      final target = game.progressionTargetScore;
      if (target <= 0) return;
      ratio = game.board.score / target;
    }
    if (ratio >= 1) {
      if (!_goalReached) {
        _goalReached = true;
        _goalPunch.trigger();
      }
    } else {
      _goalReached = false;
    }
    _goalNear = !_goalReached && ratio >= 0.8;
  }

  /// 타임바 채움은 값이 튀지 않게 따라가고, 늘어난 순간에는 그 구간을 반짝인다.
  void _updateTimeFill(double dt) {
    if (!game.hasTimedClock) {
      _timeFillRatio = null;
      return;
    }
    final target = _timeRatio();
    final shown = _timeFillRatio;
    final previous = _lastTimeRatio;
    _lastTimeRatio = target;
    if (shown == null || previous == null) {
      _timeFillRatio = target;
      return;
    }
    // 보간값이 아닌 실제 값의 증가를 비교해 보너스당 한 번만 반짝인다.
    if (target > previous + 0.00001) {
      _timeBonusFrom = math.min(shown, previous);
      _timeBonusTo = target;
      _timeBonusPunch.trigger();
    }
    _timeFillRatio = shown + (target - shown) * math.min(1, dt * 9);
  }

  void _updateItemUseFeedback() {
    if (!game.usesPhase2Inventory) return;
    for (final item in ItemKind.values) {
      final quantity = game.runInventory.quantityOf(item);
      final previous = _itemQuantities[item.index];
      if (previous >= 0 && quantity < previous) {
        _usedItem = item;
        _itemUsePunch.trigger();
      }
      _itemQuantities[item.index] = quantity;
    }
  }

  /// 콤보가 도는 동안에만 달아오르고, 끝나면 가라앉는다.
  void _updateComboHeat(double dt) {
    final state = game.board.state;
    final running = state != 'idle' && state != 'gameover';
    final combo = running ? game.board.combo : 0;
    final target = combo >= 7
        ? 1.0
        : combo >= 5
        ? 0.7
        : combo >= 3
        ? 0.45
        : 0.0;
    if (target > 0) {
      _comboHeatColor = combo >= 7
          ? const Color(0xFFFF4D4D)
          : combo >= 5
          ? const Color(0xFFFF8A3D)
          : const Color(0xFFFFC14D);
    }
    _comboHeat += (target - _comboHeat) * math.min(1, dt * 6);
    if (_comboHeat < 0.01) _comboHeat = 0;
  }

  void _renderHud(Canvas canvas) {
    final g = game;
    if (!g.hasLayout || g.size.x <= 0 || g.size.y <= 0) return;

    _renderBestBlock(canvas);
    _drawTutorialButton(canvas);
    _renderScoreBlock(canvas);
    _renderComboStrip(canvas);
    _renderTimeBar(canvas);
    _drawItemDecisionScrim(canvas);
    _drawItemConfirmPopup(canvas);
    _drawItemFeedbackBanner(canvas);
    _drawPrismColorPicker(canvas);
    _drawItemSlots(canvas);
    _drawHintButton(canvas);
    if (onRankingPressed != null && _rankingRect.width > 0) {
      _drawRankingButton(canvas);
    }
    _drawPause(canvas);
  }

  void _handleTapDown(TapDownEvent event) {
    final p = event.localPosition;
    if (_handleUiButtonTap(p)) return;
    if (game.hasPendingImmediateItemConfirm) return;
    final bt = game.board.boardY;
    final bb = game.boardPixelBottom;
    if (p.y < bt || p.y > bb) {
      if (game.activeTargetItem != null) {
        game.cancelItemTargeting();
      }
      game.dismissHint();
      return;
    }
    _boardTapPointerId = event.pointerId;
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
      event.canvasEndPosition,
      MatchGameHud._swipeThreshold,
    );
    if (swipe != null) {
      game.handleBoardSwipe(
        swipe.start.x,
        swipe.start.y,
        swipe.current.x,
        swipe.current.y,
        swipe.dr,
        swipe.dc,
      );
      return;
    }
    final draggedPosition = _drag.updateConsumedPosition(
      event.canvasEndPosition,
    );
    if (draggedPosition != null) {
      final stillDragging = game.updateInvalidBoardDrag(
        draggedPosition.x,
        draggedPosition.y,
      );
      if (!stillDragging) {
        _resetDrag();
      }
    }
  }

  void _handleDragEnd() {
    final fallbackTap = _drag.fallbackTap;
    if (fallbackTap != null) {
      game.handleBoardTap(fallbackTap.x, fallbackTap.y);
    }
    game.endBoardDrag();
    _resetDrag();
  }

  void _resetDrag() {
    _drag.reset();
  }

  bool _isUiButton(Vector2 p) {
    final o = Offset(p.x, p.y);
    return _pauseRect.contains(o) ||
        (game.hasPendingImmediateItemConfirm && _itemConfirmRect.contains(o)) ||
        _hintRect.contains(o) ||
        (onRankingPressed != null &&
            _rankingRect.width > 0 &&
            _rankingRect.contains(o)) ||
        _tutorialRect.contains(o) ||
        (game.isPrismColorPicking &&
            _prismColorRects.values.any((rect) => rect.contains(o))) ||
        (_isQaEffectPanel &&
            _debugEffectPreviewRects.values.any((rect) => rect.contains(o))) ||
        _itemRects.values.any((rect) => rect.contains(o));
  }

  bool _handleUiButtonTap(Vector2 p) {
    final o = Offset(p.x, p.y);
    if (game.hasPendingImmediateItemConfirm) {
      if (_itemConfirmCancelRect.contains(o)) {
        game.cancelImmediateItemConfirm();
        return true;
      }
      if (_itemConfirmUseRect.contains(o)) {
        game.confirmImmediateItemUse();
        return true;
      }
      return _itemConfirmRect.contains(o);
    }
    if (game.isPrismColorPicking) {
      for (final entry in _prismColorRects.entries) {
        if (entry.value.contains(o)) {
          game.selectPrismTargetColor(entry.key);
          return true;
        }
      }
    }
    if (_pauseRect.contains(o)) {
      _pressButton(_pauseRect, withSound: true);
      game.dismissHint();
      onPausePressed();
      return true;
    }
    if (_hintRect.contains(o)) {
      // 힌트는 성공했을 때 게임 쪽에서 버튼음을 낸다.
      _pressButton(_hintRect);
      onHintPressed();
      return true;
    }
    if (onRankingPressed != null &&
        _rankingRect.width > 0 &&
        _rankingRect.contains(o)) {
      _pressButton(_rankingRect, withSound: true);
      game.dismissHint();
      onRankingPressed!();
      return true;
    }
    if (_tutorialRect.contains(o)) {
      _pressButton(_tutorialRect, withSound: true);
      game.dismissHint();
      onTutorialPressed();
      return true;
    }
    if (_isQaEffectPanel) {
      for (final entry in _debugEffectPreviewRects.entries) {
        if (entry.value.contains(o)) {
          game.triggerQaSpecialEffect(
            entry.key,
            chain: _qaSpecialEffectsChainEnabled,
          );
          return true;
        }
      }
    }
    for (final entry in _itemRects.entries) {
      if (entry.value.contains(o)) {
        // 아이템 경로는 게임 쪽에서 성공·실패에 맞는 소리를 낸다.
        _pressButton(entry.value);
        game.usePhaseOneItem(entry.key);
        return true;
      }
    }
    return false;
  }

  void _tickPausedButtonPress(Duration elapsed) {
    _pressPunch.value = math.max(0, 1 - elapsed.inMicroseconds / 1000000 * 6.5);
    if (!_pressPunch.isActive) {
      _pressedRect = null;
      _pressTicker?.stop();
    }
    if (game.isAttached) game.renderBox.markNeedsPaint();
  }

  /// 누른 버튼이 짧게 눌렸다 돌아온다. 소리가 없는 버튼에만 버튼음을 붙인다.
  void _pressButton(Rect rect, {bool withSound = false}) {
    _pressedRect = rect;
    _pressPunch.trigger();
    // 메뉴가 게임 루프를 즉시 멈춰도 눌림만 끝까지 그린다. 게임 update는 호출하지 않는다.
    if (game.isAttached) {
      _pressTicker?.stop();
      (_pressTicker ??= Ticker(_tickPausedButtonPress)).start();
    }
    if (withSound) {
      SoundManager.playSfx(AssetPaths.sfxBtnSnd);
    }
  }
}
