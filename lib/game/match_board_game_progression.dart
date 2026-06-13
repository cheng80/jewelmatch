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
  }

  void _continueAfterLevelUpImpl() {
    if (!isProgressionMode) return;
    overlays.remove('LevelUp');
    overlays.remove('NoMoves');
    progressionLevel = levelUpToLevel;
    board.score = 0;
    board.lastCombo = 0;
    board.maxCombo = 0;
    timeUp = false;
    timeRemaining = roundSecondsForMode;
    _lastFlooredSecondForTimeTic = timeRemaining.floor();
    _generateFreshBoardWithStartSfx();
    _applyNextBoardBonusKinds();
    progressionNextBoardBonusKinds = const [];
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
  }

  List<GemKind> _bonusKindsForNextLevel() {
    return JewelProgressionBonus.kindsForNextLevel(
      maxCombo: board.maxCombo,
      nextLevel: levelUpToLevel,
    );
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
