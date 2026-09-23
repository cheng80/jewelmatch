part of 'match_board_logic.dart';

extension MatchBoardResolution on MatchBoardLogic {
  int _removeMarkedGemsImpl(Map<String, bool> removalSet) {
    var removed = 0;
    var hasSpecial = false;
    var specialBonus = 0;
    var timeGems = _pendingTimeGems;
    var multiplierGems = _pendingMultiplierGems;
    _pendingTimeGems = 0;
    _pendingMultiplierGems = 0;
    final plainThree = _plainThreeStep;
    _plainThreeStep = false;
    final removedCells = <({int row, int col, int color})>[];
    for (final key in removalSet.keys) {
      final parts = key.split(':');
      if (parts.length != 2) continue;
      final row = int.parse(parts[0]);
      final col = int.parse(parts[1]);
      final gem = getGem(row, col);
      if (gem != null) {
        removed++;
        stats.recordGemRemoved(gem.kind, gem.color);
        if (gem.bonus == GemBonus.time) timeGems++;
        if (gem.bonus == GemBonus.multiplier) multiplierGems++;
        if (_isSpecial(gem.kind)) {
          hasSpecial = true;
          specialBonus += _specialActivationScoreBonus(gem.kind);
        }
        removedCells.add((row: row, col: col, color: gem.color));
        cells[row][col] = null;
        _releaseGem(gem);
      }
    }

    if (_swapMoveActive) _swapMoveRemoved += removed;
    stats.timeGemsCollected += timeGems;

    if (removed > 0) {
      final base =
          MatchBoardLogic.scoreBase +
          max(0, removed - 3) * MatchBoardLogic.scoreExtraPerGem;
      final comboBonus = comboScoreMultiplier ? max(1, combo) : 1;
      // 배율은 이 단계까지 모은 m. 이 단계에서 지운 Multiplier 보석은 다음 점수부터 곱한다.
      lastRemovalScore =
          ((base + specialBonus) * comboBonus).round() * scoreMultiplier;
      // H2 상한(BR-023)은 배율을 곱한 뒤의 값에 건다.
      final scoreBudget = _hyperPairScoreBudget;
      if (scoreBudget != null) {
        lastRemovalScore = min(lastRemovalScore, scoreBudget);
        _hyperPairScoreBudget = scoreBudget - lastRemovalScore;
      }
      score += lastRemovalScore;
      stats.recordMoveScore(lastRemovalScore);
      if (multiplierGems > 0) {
        scoreMultiplier = min(
          MatchBoardLogic.maxScoreMultiplier,
          scoreMultiplier + multiplierGems,
        );
        stats.maxMultiplier = max(stats.maxMultiplier, scoreMultiplier);
      }

      final raw =
          (timedModeBonusBaseUnits +
              max(0, combo - 1) * timedModeBonusPerComboTierUnits) *
          timedModeTimeRewardScale;
      // T1: 3개짜리 일반 매치만인 콤보 1 단계는 기본 시간 보상이 없다.
      final t1Zero = timeRewardT1Active && plainThree && combo == 1;
      // 타임 보상: 정수 초만. raw>0인데 반올림이 0이 되면 최소 1초(보상 0초 금지).
      // raw<=0(예: 배율 0)이면 기본 보상 없음 — 의도적 무보상.
      var bonusSec = raw > 0 && !t1Zero ? max(1, raw.round()) : 0;
      final gemSec = timeGems * MatchBoardLogic.timeGemBonusSeconds;
      bonusSec += gemSec;
      if (onTimedModeTimeBonus != null && bonusSec > 0) {
        final timeBudget = _hyperPairTimeBudget;
        if (timeBudget != null) {
          bonusSec = min(bonusSec, timeBudget);
          _hyperPairTimeBudget = timeBudget - bonusSec;
        }
        // 상한에 걸리면 Time 보석 몫부터 센다.
        lastTimeGemSeconds = min(gemSec, bonusSec);
        if (bonusSec > 0) onTimedModeTimeBonus!(bonusSec);
        lastTimeGemSeconds = 0;
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
          gem.juiceRefillPending = true;
          setGem(row, col, gem);
          spawned++;
          missing--;
        }
      }
    }
    return spawned;
  }

  void _resolveMatchCascadeImpl(MoveInfo moveInfo) {
    _clearHyperPairBudgetIfIdle();
    pendingMoveInfo = moveInfo;
    combo = 0;
    pendingResultLabel = null;
    _beginNextResolutionCycleImpl();
  }

  /// H2 한도(BR-023)는 보드가 idle로 끝날 때 풀린다. H2 연쇄 중 안정 구역에서 둔
  /// 새 수도 같은 한도에 든다.
  void _clearHyperPairBudgetIfIdle() {
    if (state != 'idle') return;
    _hyperPairScoreBudget = null;
    _hyperPairTimeBudget = null;
  }

  void _startRemovalPhaseImpl(Map<String, bool> removalSet) {
    pendingRemovalSet = removalSet;
    state = 'removing';
    stageTimer = MatchBoardLogic.removeDelay;
    onRemovalStarted?.call(removalSet);
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
    var longest = 3;
    for (final group in matchData.groups) {
      longest = max(longest, group.length);
    }
    removalJuicePattern = spawns.any((s) => s.kind == GemKind.star)
        ? MatchJuicePattern.cross
        : longest >= 6
        ? MatchJuicePattern.sixPlus
        : longest == 5
        ? MatchJuicePattern.five
        : longest == 4
        ? MatchJuicePattern.four
        : MatchJuicePattern.normal;
    var removalSet = buildRemovalSet(matchData, spawns);
    final queue = buildSpecialQueue(removalSet);
    // T1 "3개 매치 단독": 그룹이 하나이고 그 그룹이 3개일 때만(검수 R4 P2-1).
    _plainThreeStep =
        spawns.isEmpty &&
        queue.isEmpty &&
        matchData.groups.length == 1 &&
        matchData.groups.first.length == 3;
    _consumeSpawnMaterialBonuses(spawns);

    for (final spawn in spawns) {
      stats.recordSpecialCreated(spawn.kind);
    }
    applySpawnInfo(spawns);
    _convergeOnSpawns(matchData, spawns, removalSet);
    if (spawns.isNotEmpty) onSpecialsBorn?.call(spawns);
    activateSpecials(removalSet, queue);
    pendingMoveInfo = null;
    _startRemovalPhaseImpl(removalSet);
    return true;
  }

  /// 특수 보석을 만든 매치 그룹은 제거되는 동안 생성 칸으로 빨려 들고,
  /// 생성된 보석은 탄생 팝을 시작한다. 제거 예정 보석의 화면 목표만 바꾼다.
  void _convergeOnSpawns(
    MatchData matchData,
    List<SpecialSpawn> spawns,
    Map<String, bool> removalSet,
  ) {
    for (final spawn in spawns) {
      final to = cellToPixel(spawn.row, spawn.col);
      for (final group in matchData.groups) {
        if (!group.cells.any((c) => c.x == spawn.row && c.y == spawn.col)) {
          continue;
        }
        for (final cell in group.cells) {
          if (!removalSet.containsKey(_cellKey(cell.x, cell.y))) continue;
          final gem = getGem(cell.x, cell.y);
          if (gem == null) continue;
          gem.targetX = to.dx;
          gem.targetY = to.dy;
        }
      }
      getGem(spawn.row, spawn.col)?.popT = 0;
    }
  }

  /// 특수 보석 재료가 된 속성 보석은 속성을 잃고 지운 것으로 센다.
  void _consumeSpawnMaterialBonuses(List<SpecialSpawn> spawns) {
    for (final spawn in spawns) {
      final gem = getGem(spawn.row, spawn.col);
      if (gem == null) continue;
      if (gem.bonus == GemBonus.time) _pendingTimeGems++;
      if (gem.bonus == GemBonus.multiplier) _pendingMultiplierGems++;
      gem.bonus = GemBonus.none;
    }
  }

  /// 유저 스왑 한 수가 끝나면 Multiplier를 먼저 정하고 다른 보석에 Time을 붙인다.
  void _placeBonusGemsAfterMove(int removed) {
    if (multiplierGemActive &&
        scoreMultiplier < MatchBoardLogic.maxScoreMultiplier &&
        removed >= multiplierMoveThreshold &&
        countBonusGems(GemBonus.multiplier) == 0) {
      placeBonusGem(GemBonus.multiplier);
    }
    if (timeGemActive &&
        removed >= MatchBoardLogic.timeGemMoveThreshold &&
        countBonusGems(GemBonus.time) < MatchBoardLogic.maxTimeGems) {
      placeBonusGem(GemBonus.time);
    }
  }

  bool _placeBonusGemImpl(GemBonus bonus, {required bool pop}) {
    final candidates = <BoardGem>[
      for (final row in cells)
        for (final gem in row)
          if (gem != null &&
              gem.kind == GemKind.normal &&
              gem.bonus == GemBonus.none)
            gem,
    ];
    if (candidates.isEmpty) return false;
    final gem = candidates[_random.nextInt(candidates.length)];
    gem.bonus = bonus;
    if (pop) gem.popT = 0;
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
    _hyperPairScoreBudget = null;
    _hyperPairTimeBudget = null;
    stats.finishMove();
    if (_swapMoveActive) {
      final removed = _swapMoveRemoved;
      _swapMoveActive = false;
      _swapMoveRemoved = 0;
      _placeBonusGemsAfterMove(removed);
    }

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
    removalJuicePattern = MatchJuicePattern.normal;
    _clearHyperPairBudgetIfIdle();
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
    removalJuicePattern = MatchJuicePattern.normal;
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
    if (state == 'swapSettle') {
      final move = pendingMoveInfo;
      if (move == null) return;
      for (final cell in [move.movedA, move.movedB]) {
        final gem = getGem(cell.x, cell.y);
        if (gem != null) {
          gem.x = gem.targetX;
          gem.y = gem.targetY;
        }
      }
      resolveMatchCascade(move);
      return;
    }
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
