part of 'match_board_game.dart';

extension MatchBoardGameProgression on MatchBoardGame {
  void _updateProgressionMode() {
    if (!isProgressionMode ||
        !isPlaying ||
        timeUp ||
        board.introFillInProgress ||
        board.state != 'idle' ||
        hasActiveVisualEffects) {
      return;
    }
    if (board.score < progressionTargetScore) return;
    final nextLevel = progressionLevel + 1;
    levelUpFromLevel = progressionLevel;
    levelUpToLevel = nextLevel;
    progressionNextBoardBonusKinds = _bonusKindsForNextLevel();
    _grantStageRewardsOnce();
    GameSettings.saveBestProgressionRecordIfBetter(
      level: levelUpToLevel,
      score: board.score,
    );
    isPlaying = false;
    pauseEngine();
    overlays.add('LevelCelebration');
    SoundManager.playSfx(AssetPaths.sfxLevelUp);
  }

  void _resetProgressionRound() {
    progressionLevel = 1;
    levelUpFromLevel = 1;
    levelUpToLevel = 1;
    progressionNextBoardBonusKinds = const [];
    latestStageRewards = const [];
    stageLoadoutOpenSlotCount = StageLoadout.phase2InitialOpenSlotCount;
    recentlyUnlockedLoadoutSlotIndices = const [];
    _recentStageRewardTotals.clear();
    _stageRewardClaimKey = null;
  }

  void _continueAfterLevelUpImpl() {
    if (!isProgressionMode) return;
    overlays.remove('LevelUp');
    overlays.remove('StageInventory');
    overlays.remove('NoMoves');
    progressionLevel = levelUpToLevel;
    _remainingHints += MatchBoardGame.progressionModeHintsPerStage;
    board.score = 0;
    board.lastCombo = 0;
    board.maxCombo = 0;
    stageLoadout = nextStageLoadoutDraft;
    timeUp = false;
    timeRemaining = roundSecondsForMode;
    _lastFlooredSecondForTimeTic = timeRemaining.floor();
    _generateFreshBoardWithStartSfx();
    _applyNextBoardBonusKinds();
    nextStageLoadoutDraft = stageLoadout;
    progressionNextBoardBonusKinds = const [];
    latestStageRewards = const [];
    recentlyUnlockedLoadoutSlotIndices = const [];
    _stageRewardClaimKey = null;
    _stageStartRemainingHints = _remainingHints;
    _syncIntroInputBlock();
    resumeEngine();
    isPlaying = true;
  }

  void _showLevelUpPopupAfterCelebrationImpl() {
    if (!isProgressionMode) return;
    overlays.remove('LevelCelebration');
    if (!overlays.isActive('LevelUp')) {
      overlays.add('LevelUp');
    }
    if (hasPendingStageInventoryUnlock) {
      overlays.add('StageInventory');
    }
  }

  List<GemKind> _bonusKindsForNextLevel() {
    return JewelProgressionBonus.kindsForNextLevel(
      maxCombo: board.maxCombo,
      nextLevel: levelUpToLevel,
    );
  }

  void _grantStageRewardsOnce() {
    final claimKey = '$levelUpFromLevel->$levelUpToLevel:${board.score}';
    if (_stageRewardClaimKey == claimKey) return;
    final rewards = StageRewardEvaluator.evaluate(
      stats: board.stats,
      score: board.score,
      targetScore: progressionTargetScore,
      maxCombo: board.maxCombo,
      remainingHints: _remainingHints,
      stageStartRemainingHints: _stageStartRemainingHints,
      isClear: true,
    );
    for (final reward in rewards) {
      runInventory.add(reward.item, reward.quantity);
    }
    latestStageRewards = List<StageRewardGrant>.unmodifiable(rewards);
    _stageRewardClaimKey = claimKey;
    _recordStageRewardTotal(
      rewards.fold<int>(0, (total, reward) => total + reward.quantity),
    );
    _updateLoadoutUnlocksForClear();
    nextStageLoadoutDraft = nextStageLoadoutDraft.withOpenSlotCount(
      stageLoadoutOpenSlotCount,
    );
  }

  void _recordStageRewardTotal(int total) {
    _recentStageRewardTotals.add(total);
    if (_recentStageRewardTotals.length > 3) {
      _recentStageRewardTotals.removeAt(0);
    }
  }

  void _updateLoadoutUnlocksForClear() {
    final before = stageLoadoutOpenSlotCount;
    var target = before;
    if (levelUpFromLevel >= StageLoadout.phase2Slot3UnlockClearLevel) {
      target = target < 3 ? 3 : target;
    }
    final hasRecentMultiReward = _recentStageRewardTotals.any(
      (total) => total >= 2,
    );
    if (levelUpFromLevel >= StageLoadout.phase2Slot4UnlockClearLevel &&
        hasRecentMultiReward) {
      target = StageLoadout.phase2SlotCount;
    }
    if (target == before) {
      recentlyUnlockedLoadoutSlotIndices = const [];
      return;
    }
    stageLoadoutOpenSlotCount = target;
    recentlyUnlockedLoadoutSlotIndices = [
      for (var slot = before; slot < target; slot++) slot,
    ];
  }

  void _applyNextBoardBonusKinds() {
    const cells = [(row: 3, col: 3), (row: 4, col: 4), (row: 3, col: 4)];
    for (var i = 0; i < progressionNextBoardBonusKinds.length; i++) {
      final target = cells[i];
      final gem = board.getGem(target.row, target.col);
      if (gem == null) continue;
      final kind = progressionNextBoardBonusKinds[i];
      gem.kind = kind;
      if (kind == GemKind.hyper) {
        gem.color = 0;
      }
    }
  }

  void debugTriggerProgressionLevelUp() {
    if (!isProgressionMode ||
        overlays.isActive('LevelUp') ||
        overlays.isActive('LevelCelebration')) {
      return;
    }
    board.score = JewelRankProgression.scoreTargetForLevel(progressionLevel);
    board.maxCombo = 5;
  }
}
