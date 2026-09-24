part of 'match_board_game.dart';

extension MatchBoardGameFlow on MatchBoardGame {
  /// [newRound]가 false면 판 도중 새 보드(NoMoves)라 일일 시드를 다시 쓰지 않는다.
  void _generateFreshBoardWithStartSfx({
    BoardFillIntroKind introKind = BoardFillIntroKind.roundStart,
    bool pauseIntroUntilRelease = false,
    bool newRound = true,
  }) {
    // 실험 기능 스위치는 새 판(첫 보드, 다시 하기, 다음 레벨)에서만 다시 읽는다.
    if (newRound) {
      board.flags = GameplayFlags.current;
      board.flagsFromUrl = GameplayFlags.currentFromUrl;
      board.colorCount = board.flags.colorCountFor(
        progressionMode: isProgressionMode,
        level: progressionLevel,
      );
    }
    // 타임 모드는 판 시작 시각의 KST 날짜 시드를 쓴다. 판 도중 자정이 지나도 유지한다.
    if (newRound && isTimedMode) {
      final key = DailySeed.keyFor(DateTime.now());
      board.startDailyBoard(key);
      // Last Hurrah 하이퍼 색도 같은 날 같은 입력이면 같게 나오도록 보드 난수와 분리된 날짜 난수를 쓴다.
      lastHurrahRandom = DailyRandom(
        DailySeed.seedFor(key) ^ MatchBoardGame.lastHurrahSeedSalt,
      );
    }
    // NoMoves 새 보드(newRound false)는 판 통계를 유지한다. 도전 스테이지 진행도와 결과 통계가 이어진다.
    board.generateFreshBoard(introKind: introKind, resetStats: newRound);
    if (introKind == BoardFillIntroKind.roundStart) {
      board.introFillPaused = pauseIntroUntilRelease;
      _playStartSfxWhenBoardReady();
    }
  }

  void releaseRoundStartIntro() {
    if (board.introFillInProgress) {
      board.introFillPaused = false;
    }
  }

  void _pauseGameImpl() {
    if (!isPlaying || timeUp) return;
    cancelItemTargeting();
    isPlaying = false;
    SoundManager.pauseBgm();
    pauseEngine();
    overlays.add('PauseMenu');
  }

  void _showNoMovesOverlayImpl() {
    if (timeUp || lastHurrahActive || overlays.isActive('NoMoves')) return;
    isPlaying = false;
    SoundManager.pauseBgm();
    pauseEngine();
    overlays.add('NoMoves');
  }

  void _resumeGameImpl() {
    if (timeUp) return;
    SoundManager.resumeBgm(onlyIfCurrent: AssetPaths.bgmMain);
    resumeEngine();
    overlays.remove('PauseMenu');
    overlays.remove('RankingList');
    isPlaying = true;
  }

  void _pauseForRankingPopupImpl() {
    if (!isTimedMode || !isPlaying || timeUp) return;
    isPlaying = false;
    SoundManager.pauseBgm();
    pauseEngine();
    overlays.add('RankingList');
  }

  void _closeRankingPopupImpl() {
    if (timeUp) return;
    overlays.remove('RankingList');
    SoundManager.resumeBgm(onlyIfCurrent: AssetPaths.bgmMain);
    resumeEngine();
    isPlaying = true;
  }

  void _restartRoundImpl() {
    // 일시정지 다시 하기도 판 종료로 반영한다. TimeUp 뒤에는 이미 반영했다.
    if (!timeUp) logRoundEnd('restart');
    _stageAttemptSerial += 1;
    overlays.remove('TimeUp');
    overlays.remove('PauseMenu');
    overlays.remove('NoMoves');
    overlays.remove('HowToPlay');
    overlays.remove('RankingList');
    overlays.remove('LevelCelebration');
    overlays.remove('LevelUp');
    overlays.remove('StageInventory');
    overlays.remove('GameStats');
    timeUp = false;
    _lastHurrah = null;
    _lastHurrahBadge.hide();
    board.endLastHurrahRules();
    activeTargetItem = null;
    board.score = 0;
    board.lastCombo = 0;
    board.maxCombo = 0;
    _lastSavedScore = -1;
    if (isProgressionMode) {
      _resetProgressionRound();
    }
    runInventory = RunInventory.phase2Initial();
    stageLoadoutOpenSlotCount = StageLoadout.phase2InitialOpenSlotCount;
    recentlyUnlockedLoadoutSlotIndices = const [];
    _recentStageRewardTotals.clear();
    stageLoadout = StageLoadout.phase2Default(
      runInventory,
      openSlotCount: stageLoadoutOpenSlotCount,
    );
    nextStageLoadoutDraft = stageLoadout;
    latestStageRewards = const [];
    _stageRewardClaimKey = null;
    _remainingHints = MatchBoardGame._initialHintsForMode(gameMode);
    _stageStartRemainingHints = _remainingHints;
    if (hasTimedClock) {
      timeRemaining = roundSecondsForMode;
      _lastFlooredSecondForTimeTic = timeRemaining.floor();
    }
    _generateFreshBoardWithStartSfx();
    // 새 판의 일일 키가 정해진 뒤 기록한다.
    _logRoundStart();
    _syncIntroInputBlock();
    resumeEngine();
    isPlaying = true;
    SoundManager.playBgm(AssetPaths.bgmMain);
    // 게임 화면을 켜 둔 채 주가 바뀌어도 새 판에서는 이번 주 1위를 다시 보여 준다.
    if (isTimedMode) {
      _fetchTop1();
    }
  }

  bool _continueStageAfterAdImpl() {
    if (!isProgressionMode || !timeUp) return false;
    EventLogger.instance.log('stage_continue', {'level': progressionLevel});
    overlays.remove('TimeUp');
    overlays.remove('GameStats');
    timeUp = false;
    timeRemaining = roundSecondsForMode;
    _lastFlooredSecondForTimeTic = timeRemaining.floor();
    resumeEngine();
    isPlaying = true;
    SoundManager.resumeBgm(onlyIfCurrent: AssetPaths.bgmMain);
    return true;
  }

  void _requestHintImpl() {
    if (!isPlaying ||
        timeUp ||
        board.inputLocked ||
        board.introFillInProgress) {
      return;
    }
    if (board.state != 'idle') return;
    if (hasLimitedHints && _remainingHints <= 0) return;
    if (board.showHint()) {
      if (hasLimitedHints) {
        _remainingHints -= 1;
      }
      SoundManager.playSfx(AssetPaths.sfxBtnSnd);
    }
  }

  void _dismissHintImpl() => board.clearHint();

  void _showHowToPlayImpl() {
    if (!isPlaying || timeUp) return;
    cancelItemTargeting();
    isPlaying = false;
    SoundManager.pauseBgm();
    pauseEngine();
    overlays.add('HowToPlay');
  }

  void _closeHowToPlayImpl() {
    if (timeUp) return;
    SoundManager.resumeBgm(onlyIfCurrent: AssetPaths.bgmMain);
    resumeEngine();
    overlays.remove('HowToPlay');
    isPlaying = true;
  }

  void _showGameStatsImpl() {
    if (!timeUp &&
        !overlays.isActive('NoMoves') &&
        !overlays.isActive('PauseMenu') &&
        !overlays.isActive('LevelUp')) {
      return;
    }
    overlays.add('GameStats');
  }

  void _closeGameStatsImpl() {
    overlays.remove('GameStats');
  }

  void _showStageInventoryImpl() {
    if (!overlays.isActive('StageInventory')) {
      overlays.add('StageInventory');
    }
  }

  void _closeStageInventoryImpl() {
    overlays.remove('StageInventory');
  }

  void _shuffleBoardImpl() {
    final shouldResume = overlays.isActive('NoMoves') && !timeUp;
    board.shuffle();
    overlays.remove('NoMoves');
    overlays.remove('GameStats');
    _syncIntroInputBlock();
    if (shouldResume) {
      SoundManager.resumeBgm(onlyIfCurrent: AssetPaths.bgmMain);
      resumeEngine();
      isPlaying = true;
    }
  }

  void _newBoardImpl() {
    final shouldResume = overlays.isActive('NoMoves') && !timeUp;
    _generateFreshBoardWithStartSfx(newRound: false);
    overlays.remove('NoMoves');
    overlays.remove('GameStats');
    _syncIntroInputBlock();
    if (shouldResume) {
      SoundManager.resumeBgm(onlyIfCurrent: AssetPaths.bgmMain);
      resumeEngine();
      isPlaying = true;
    }
  }
}
