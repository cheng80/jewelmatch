part of 'match_board_game.dart';

extension MatchBoardGameFlow on MatchBoardGame {
  void _generateFreshBoardWithStartSfx({
    BoardFillIntroKind introKind = BoardFillIntroKind.roundStart,
  }) {
    if (introKind == BoardFillIntroKind.roundStart) {
      SoundManager.playSfx(AssetPaths.sfxStart);
    }
    board.generateFreshBoard(introKind: introKind);
  }

  void _pauseGameImpl() {
    if (!isPlaying || timeUp) return;
    isPlaying = false;
    SoundManager.pauseBgm();
    pauseEngine();
    overlays.add('PauseMenu');
  }

  void _showNoMovesOverlayImpl() {
    if (timeUp || overlays.isActive('NoMoves')) return;
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
    overlays.remove('TimeUp');
    overlays.remove('PauseMenu');
    overlays.remove('NoMoves');
    overlays.remove('HowToPlay');
    overlays.remove('RankingList');
    overlays.remove('LevelCelebration');
    overlays.remove('LevelUp');
    overlays.remove('GameStats');
    timeUp = false;
    board.score = 0;
    board.lastCombo = 0;
    board.maxCombo = 0;
    _lastSavedScore = -1;
    if (isProgressionMode) {
      _resetProgressionRound();
    }
    if (hasTimedClock) {
      timeRemaining = roundSecondsForMode;
      _lastFlooredSecondForTimeTic = timeRemaining.floor();
    }
    _generateFreshBoardWithStartSfx();
    _syncIntroInputBlock();
    resumeEngine();
    isPlaying = true;
    SoundManager.playBgm(AssetPaths.bgmMain);
  }

  void _requestHintImpl() {
    if (!isPlaying ||
        timeUp ||
        board.inputLocked ||
        board.introFillInProgress) {
      return;
    }
    if (board.state != 'idle') return;
    if (board.showHint()) {
      SoundManager.playSfx(AssetPaths.sfxBtnSnd);
    }
  }

  void _dismissHintImpl() => board.clearHint();

  void _showHowToPlayImpl() {
    if (!isPlaying || timeUp) return;
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
        !overlays.isActive('PauseMenu')) {
      return;
    }
    overlays.add('GameStats');
  }

  void _closeGameStatsImpl() {
    overlays.remove('GameStats');
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
    _generateFreshBoardWithStartSfx();
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
