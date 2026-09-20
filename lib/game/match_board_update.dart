part of 'match_board_logic.dart';

extension MatchBoardUpdate on MatchBoardLogic {
  void _updateImpl(double dt) {
    _updateIdleHint(dt);
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

  void _updateIdleHint(double dt) {
    if (!idleHintsEnabled ||
        state != 'idle' ||
        inputLocked ||
        introFillInProgress ||
        _invalidDragGem != null ||
        _invalidDragReturnGem != null) {
      idleHintElapsed = 0;
      if (_automaticHintVisible) clearHint();
      return;
    }
    if (_hintA != null) return;
    for (final row in cells) {
      for (final gem in row) {
        if (gem != null && (!_isGemVisuallySettled(gem) || gem.bumpT >= 0)) {
          idleHintElapsed = 0;
          return;
        }
      }
    }
    final previous = idleHintElapsed;
    idleHintElapsed += dt;
    if (previous < 5 && idleHintElapsed >= 5) {
      _automaticHintVisible = showHint();
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
        _tickGemJuice(gem, dt);
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
          if (gem.bumpT >= 0) {
            gem.bumpT += dt;
            final p = (gem.bumpT / 0.18).clamp(0.0, 1.0);
            final offset = sin(p * pi) * (1 - p * 0.35);
            gem.x = gem.targetX + gem.bumpX * offset;
            gem.y = gem.targetY + gem.bumpY * offset;
            if (p >= 1) {
              gem.bumpT = -1;
              gem.x = gem.targetX;
              gem.y = gem.targetY;
            }
            _tickGemJuice(gem, dt);
            continue;
          }
          final s = min(1.0, dt * MatchBoardLogic.tweenSpeed);
          gem.x += (gem.targetX - gem.x) * s;
          gem.y += (gem.targetY - gem.y) * s;
          _tickGemJuice(gem, dt);
        }
      }
    }
  }

  /// 반 칸 넘게 떨어지던 보석이 목표 근처에 닿으면 착지 스쿼시를 시작하고,
  /// 렌더 전용 연출 타이머를 진행한다.
  void _tickGemJuice(BoardGem gem, double dt) {
    final dy = gem.targetY - gem.y;
    if (dy > tileSize * 0.5) {
      gem.airborne = true;
    } else if (gem.airborne && dy <= tileSize * 0.12) {
      gem.airborne = false;
      gem.landT = 0;
    }
    if (gem.landT >= 0) {
      gem.landT += dt;
      if (gem.landT >= MatchBoardLogic.landSquashDuration) gem.landT = -1;
    }
    if (gem.popT >= 0) {
      gem.popT += dt;
      if (gem.popT >= MatchBoardLogic.spawnPopDuration) gem.popT = -1;
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
