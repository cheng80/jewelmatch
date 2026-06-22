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
        stats.recordGemRemoved(gem.kind);
        if (_isSpecial(gem.kind)) {
          hasSpecial = true;
          specialBonus += _specialActivationScoreBonus(gem.kind);
        }
        removedCells.add((row: row, col: col, color: gem.color));
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
    stats.recordMatchGroups(matchData.groups.length);

    final mi = pendingMoveInfo;
    final spawns = classifyMatchGroups(matchData, mi?.movedA, mi?.movedB);
    var removalSet = buildRemovalSet(matchData, spawns);
    final queue = buildSpecialQueue(removalSet);

    for (final spawn in spawns) {
      stats.recordSpecialCreated(spawn.kind);
    }
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

  bool _removeSingleCellForItemImpl(int row, int col) {
    if (inputLocked || state != 'idle' || !isInside(row, col)) return false;
    if (getGem(row, col) == null) return false;
    combo = 1;
    lastCombo = 1;
    if (maxCombo < 1) {
      maxCombo = 1;
    }
    pendingResultLabel = 'rune hammer';
    _startRemovalPhaseImpl({_cellKey(row, col): true});
    return true;
  }

  bool _useBoardItemImpl(
    ItemKind item, {
    required int row,
    required int col,
    int? prismColor,
  }) {
    if (item == ItemKind.prismTransform && prismColor != null) {
      return _transformCellForPrismItemImpl(row, col, prismColor: prismColor);
    }
    return switch (item) {
      ItemKind.runeHammer => _removeSingleCellForItemImpl(row, col),
      ItemKind.ancientBomb => _triggerAreaItemImpl(
        row,
        col,
        GemKind.bomb,
        'ancient bomb',
      ),
      ItemKind.thorHammer => _triggerAreaItemImpl(
        row,
        col,
        GemKind.star,
        'thor hammer',
      ),
      ItemKind.hyperCube => _triggerHyperCubeItemImpl(row, col),
      ItemKind.prismTransform => _transformCellForPrismItemImpl(row, col),
      ItemKind.fateShuffle || ItemKind.timeSlip || ItemKind.hintPlus => false,
    };
  }

  bool _triggerAreaItemImpl(int row, int col, GemKind kind, String label) {
    if (inputLocked || state != 'idle' || !isInside(row, col)) return false;
    if (getGem(row, col) == null) return false;
    final removalSet = <String, bool>{_cellKey(row, col): true};
    final queue = <MatchChainItem>[
      MatchChainItem(row: row, col: col, kind: kind, triggerColor: null),
    ];
    resolveSpecialSwap(removalSet, queue, label);
    return true;
  }

  bool _triggerHyperCubeItemImpl(int row, int col) {
    if (inputLocked || state != 'idle' || !isInside(row, col)) return false;
    final gem = getGem(row, col);
    if (gem == null || gem.kind != GemKind.normal) return false;
    final removalSet = <String, bool>{_cellKey(row, col): true};
    final queue = <MatchChainItem>[
      MatchChainItem(
        row: row,
        col: col,
        kind: GemKind.hyper,
        triggerColor: gem.color,
      ),
    ];
    resolveSpecialSwap(removalSet, queue, 'hyper cube');
    return true;
  }

  bool _transformCellForPrismItemImpl(int row, int col, {int? prismColor}) {
    if (inputLocked || state != 'idle' || !isInside(row, col)) return false;
    final gem = getGem(row, col);
    if (gem == null || gem.kind != GemKind.normal) return false;

    final original = gem.color;
    if (prismColor != null) {
      if (prismColor < 1 || prismColor > colorCount) return false;
      gem.color = prismColor;
    } else {
      var chosen = 0;
      for (var color = 1; color <= colorCount; color++) {
        if (color == original) continue;
        gem.color = color;
        if (findMatchesAt(row, col).groups.isNotEmpty) {
          chosen = color;
          break;
        }
      }
      if (chosen == 0) {
        chosen = original % colorCount + 1;
        gem.color = chosen;
      }
    }

    selected = null;
    pendingResultLabel = 'prism';
    final matchData = findAllMatches();
    if (matchData.groups.isEmpty) {
      lastActionText = 'prism';
      return true;
    }
    resolveMatchCascade(
      MoveInfo(movedA: Point(row, col), movedB: Point(row, col)),
    );
    return true;
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
