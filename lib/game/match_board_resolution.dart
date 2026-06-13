part of 'match_board_logic.dart';

extension MatchBoardResolution on MatchBoardLogic {
  int _removeMarkedGemsImpl(Map<String, bool> removalSet) {
    var removed = 0;
    var hasSpecial = false;
    var specialBonus = 0;
    final removedCells = <({int row, int col, int color})>[];
    for (final key in removalSet.keys) {
      final parts = key.split(':');
      if (parts.length != 2) continue;
      final row = int.parse(parts[0]);
      final col = int.parse(parts[1]);
      final gem = getGem(row, col);
      if (gem != null) {
        removed++;
        if (_isSpecial(gem.kind)) {
          hasSpecial = true;
          specialBonus += _specialActivationScoreBonus(gem.kind);
        }
        removedCells.add((row: row, col: col, color: gem.color));
        addFlashEffect(row, col);
        cells[row][col] = null;
        _releaseGem(gem);
      }
    }

    if (removed > 0) {
      final base =
          MatchBoardLogic.scoreBase +
          max(0, removed - 3) * MatchBoardLogic.scoreExtraPerGem;
      final comboBonus = max(1, combo);
      score += ((base + specialBonus) * comboBonus).round();

      final raw =
          (timedModeBonusBaseUnits +
              max(0, combo - 1) * timedModeBonusPerComboTierUnits) *
          timedModeTimeRewardScale;
      // 타임 보상: 정수 초만. raw>0인데 반올림이 0이 되면 최소 1초(보상 0초 금지).
      // raw<=0(예: 배율 0)이면 콜백 없음 — 의도적 무보상.
      if (onTimedModeTimeBonus != null && raw > 0) {
        var bonusSec = raw.round();
        if (bonusSec < 1) {
          bonusSec = 1;
        }
        onTimedModeTimeBonus!(bonusSec);
      }

      if (onGemsRemoved != null && removedCells.isNotEmpty) {
        final bigMatch =
            _lastMatchData?.groups.any((g) => g.length >= 4) ?? false;
        onGemsRemoved!(removedCells, bigMatch, hasSpecial, combo);
      }
    }
    return removed;
  }

  bool _applyGravityImpl() {
    var moved = false;
    for (var col = 0; col < cols; col++) {
      var writeRow = rows - 1;
      for (var row = rows - 1; row >= 0; row--) {
        final gem = cells[row][col];
        if (gem != null) {
          if (writeRow != row) {
            cells[writeRow][col] = gem;
            cells[row][col] = null;
            gem.row = writeRow;
            gem.col = col;
            _updateGemTarget(gem);
            moved = true;
          }
          writeRow--;
        }
      }
      for (var row = writeRow; row >= 0; row--) {
        cells[row][col] = null;
      }
    }
    return moved;
  }

  int _refillBoardImpl() {
    var spawned = 0;
    for (var col = 0; col < cols; col++) {
      var missing = 0;
      for (var row = 0; row < rows; row++) {
        if (cells[row][col] == null) missing++;
      }
      for (var row = 0; row < rows; row++) {
        if (cells[row][col] == null) {
          final color = _random.nextInt(colorCount) + 1;
          final gem = createGem(
            row,
            col,
            color,
            GemKind.normal,
            spawnOffsetRows: missing,
          );
          setGem(row, col, gem);
          spawned++;
          missing--;
        }
      }
    }
    return spawned;
  }

  void _resolveMatchCascadeImpl(MoveInfo moveInfo) {
    pendingMoveInfo = moveInfo;
    combo = 0;
    pendingResultLabel = null;
    _beginNextResolutionCycleImpl();
  }

  void _startRemovalPhaseImpl(Map<String, bool> removalSet) {
    pendingRemovalSet = removalSet;
    state = 'removing';
    stageTimer = MatchBoardLogic.removeDelay;
  }

  bool _beginNextResolutionCycleImpl() {
    final matchData = findAllMatches();
    if (matchData.groups.isEmpty) {
      _finishResolutionFlowImpl();
      return false;
    }

    combo++;
    lastCombo = combo;
    if (combo > maxCombo) {
      maxCombo = combo;
    }

    _lastMatchData = matchData;

    final mi = pendingMoveInfo;
    final spawns = classifyMatchGroups(matchData, mi?.movedA, mi?.movedB);
    var removalSet = buildRemovalSet(matchData, spawns);
    final queue = buildSpecialQueue(removalSet);

    applySpawnInfo(spawns);
    activateSpecials(removalSet, queue);
    pendingMoveInfo = null;
    _startRemovalPhaseImpl(removalSet);
    return true;
  }

  void _finishResolutionFlowImpl() {
    if (pendingResultLabel != null) {
      lastActionText = pendingResultLabel!;
    } else if (combo > 1) {
      lastActionText = 'combo x$combo';
    } else if (combo == 1) {
      lastActionText = 'match';
    }

    pendingResultLabel = null;
    pendingMoveInfo = null;
    pendingRemovalSet = null;
    combo = 0;

    state = 'idle';
    selected = null;

    if (!hasAnyValidMove()) {
      lastActionText = 'no moves';
      onNoMoves?.call();
    }
  }

  void _resolveSpecialSwapImpl(
    Map<String, bool> removalSet,
    List<MatchChainItem> queue,
    String label,
  ) {
    combo = 1;
    lastCombo = 1;
    if (maxCombo < 1) {
      maxCombo = 1;
    }
    pendingResultLabel = label;
    activateSpecials(removalSet, queue);
    _startRemovalPhaseImpl(removalSet);
  }

  void _advanceResolutionStepImpl() {
    if (state == 'removing') {
      _removeMarkedGemsImpl(pendingRemovalSet ?? {});
      state = 'falling';
      stageTimer = MatchBoardLogic.fallingDelay;
      return;
    }
    if (state == 'falling') {
      _applyGravityImpl();
      state = 'refilling';
      stageTimer = MatchBoardLogic.refillDelay;
      return;
    }
    if (state == 'refilling') {
      _refillBoardImpl();
      state = 'checking';
      stageTimer = MatchBoardLogic.checkingDelay;
      return;
    }
    if (state == 'checking') {
      pendingRemovalSet = null;
      _beginNextResolutionCycleImpl();
    }
  }
}

int _specialActivationScoreBonus(GemKind kind) {
  return switch (kind) {
    GemKind.row || GemKind.col => 300,
    GemKind.bomb => 500,
    GemKind.star => 800,
    GemKind.hyper => 1200,
    GemKind.supernova => 2000,
    GemKind.normal => 0,
  };
}
