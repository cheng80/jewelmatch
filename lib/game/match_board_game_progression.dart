part of 'match_board_game.dart';

extension MatchBoardGameProgression on MatchBoardGame {
  /// Overlay 콜백이 재시작/다음 스테이지의 축하를 끝내지 않도록 런을 구분한다.
  int get levelCelebrationAttempt => _stageAttemptSerial;

  bool isCurrentLevelCelebration(int attempt) =>
      attempt == _stageAttemptSerial &&
      isProgressionMode &&
      !isPlaying &&
      !timeUp &&
      overlays.isActive('LevelCelebration');

  void _updateProgressionMode() {
    if (!isProgressionMode ||
        !isPlaying ||
        timeUp ||
        board.introFillInProgress ||
        board.state != 'idle' ||
        hasActiveVisualEffects) {
      return;
    }
    final challenge = stageChallenge;
    final cleared = challenge == null
        ? board.score >= progressionTargetScore
        : challenge.isComplete(board.stats);
    if (!cleared) return;
    final nextLevel = progressionLevel + 1;
    levelUpFromLevel = progressionLevel;
    levelUpToLevel = nextLevel;
    EventLogger.instance.log('level_clear', {
      'level': progressionLevel,
      'score': board.score,
      'max_combo': board.maxCombo,
      if (challenge != null) 'challenge': challenge.kind.name,
    });
    progressionNextBoardBonusKinds = _bonusKindsForNextLevel();
    _grantStageRewardsOnce();
    commitRecords(level: levelUpToLevel);
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
    _stageAttemptSerial += 1;
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
    if (stageChallenge != null) {
      _showItemFeedback(
        localeString('challengeStage', 'Challenge Stage'),
        seconds: 2.4,
      );
    }
  }

  void _showLevelUpPopupAfterCelebrationImpl() {
    if (!isCurrentLevelCelebration(_stageAttemptSerial)) return;
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
      // 도전 스테이지는 목표 달성을 targetRatio 1.0으로 본다.
      targetScore: stageChallenge == null
          ? progressionTargetScore
          : board.score,
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
    if (Uri.base.queryParameters['qaSixRewards'] == '1') {
      levelUpFromLevel = progressionLevel;
      levelUpToLevel = progressionLevel + 1;
      progressionNextBoardBonusKinds = _bonusKindsForNextLevel();
      latestStageRewards = const [
        StageRewardGrant(
          item: ItemKind.runeHammer,
          quantity: 1,
          reasonKey: 'qa',
        ),
        StageRewardGrant(
          item: ItemKind.ancientBomb,
          quantity: 1,
          reasonKey: 'qa',
        ),
        StageRewardGrant(
          item: ItemKind.thorHammer,
          quantity: 1,
          reasonKey: 'qa',
        ),
        StageRewardGrant(
          item: ItemKind.hyperCube,
          quantity: 1,
          reasonKey: 'qa',
        ),
        StageRewardGrant(
          item: ItemKind.prismTransform,
          quantity: 1,
          reasonKey: 'qa',
        ),
        StageRewardGrant(
          item: ItemKind.fateShuffle,
          quantity: 1,
          reasonKey: 'qa',
        ),
      ];
      isPlaying = false;
      pauseEngine();
      overlays.add('LevelUp');
      return;
    }
    board.score = JewelRankProgression.scoreTargetForLevel(progressionLevel);
    board.maxCombo = 5;
    debugFillStageChallenge();
  }

  /// QA 전용: 도전 스테이지 목표를 채운 통계로 만든다.
  void debugFillStageChallenge() {
    final challenge = stageChallenge;
    if (challenge == null) return;
    final stats = board.stats;
    switch (challenge.kind) {
      case StageChallengeKind.color:
        stats.removedNormalByColor[challenge.color!] = challenge.target;
      case StageChallengeKind.special:
        stats.specialGemsActivated = challenge.target;
      case StageChallengeKind.gems:
        stats.removedGems = challenge.target;
    }
  }
}
