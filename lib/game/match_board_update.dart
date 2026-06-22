part of 'match_board_logic.dart';

extension MatchBoardUpdate on MatchBoardLogic {
  void _updateImpl(double dt) {
    if (inputLocked && !introFillInProgress) {
      lockTimer -= dt;
      if (lockTimer <= 0) {
        inputLocked = false;
        lockTimer = 0;
      }
    }

    if (state != 'idle' && state != 'gameover') {
      stageTimer -= dt;
      if (stageTimer <= 0) {
        advanceResolutionStep();
      }
    }

    if (introFillInProgress) {
      if (!introFillPaused) {
        _updateIntroFill(dt);
      }
    } else {
      _updateGemTweens(dt);
    }
  }

  void _updateIntroFill(double dt) {
    final activeRow = _introActiveRow;
    final s = min(1.0, dt * MatchBoardLogic.introTweenSpeed);
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
          gem.y += (gem.targetY - gem.y) * s;
          if ((gem.targetY - gem.y).abs() <= 0.45) {
            gem.y = gem.targetY;
          }
        }
      }
    }

    var waveComplete = true;
    for (var c = 0; c < cols; c++) {
      final g = cells[activeRow][c];
      if (g == null) continue;
      if ((g.targetY - g.y).abs() > 0.45) {
        waveComplete = false;
        break;
      }
    }
    if (waveComplete) {
      _introWaveIndex++;
      if (_introWaveIndex >= rows) {
        introFillInProgress = false;
        introFillPaused = false;
        _introWaveIndex = 0;
        onIntroFillComplete?.call(_pendingIntroKind);
      }
    }
  }

  void _updateGemTweens(double dt) {
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final gem = cells[r][c];
        if (gem != null) {
          if (identical(gem, _invalidDragGem)) continue;
          if (identical(gem, _invalidDragReturnGem)) {
            _updateInvalidDragReturn(gem, dt);
            continue;
          }
          final s = min(1.0, dt * MatchBoardLogic.tweenSpeed);
          gem.x += (gem.targetX - gem.x) * s;
          gem.y += (gem.targetY - gem.y) * s;
        }
      }
    }
  }

  void _updateInvalidDragReturn(BoardGem gem, double dt) {
    _invalidDragReturnElapsed += dt;
    final t =
        (_invalidDragReturnElapsed / MatchBoardLogic.invalidDragReturnDuration)
            .clamp(0.0, 1.0);
    if (t >= 1) {
      gem.x = gem.targetX;
      gem.y = gem.targetY;
      _invalidDragReturnGem = null;
      _invalidDragReturnElapsed = 0;
      return;
    }

    final eased = _easeOutBack(t);
    gem.x =
        _invalidDragReturnStartX +
        (gem.targetX - _invalidDragReturnStartX) * eased;
    gem.y =
        _invalidDragReturnStartY +
        (gem.targetY - _invalidDragReturnStartY) * eased;
  }

  double _easeOutBack(double t) {
    const c1 = MatchBoardLogic._invalidDragReturnOvershoot;
    const c3 = c1 + 1;
    final p = t - 1;
    return 1 + c3 * p * p * p + c1 * p * p;
  }
}
