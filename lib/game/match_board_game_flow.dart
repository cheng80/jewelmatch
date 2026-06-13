part of 'match_board_game.dart';

extension MatchBoardGameFlow on MatchBoardGame {
  void _pauseGameImpl() {
    if (!isPlaying || timeUp) return;
    isPlaying = false;
    SoundManager.pauseBgm();
    pauseEngine();
    overlays.add('PauseMenu');
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
    timeUp = false;
    board.score = 0;
    board.lastCombo = 0;
    board.maxCombo = 0;
    _lastSavedScore = -1;
    if (isTimedMode) {
      timeRemaining = MatchBoardGame.timedRoundSeconds;
      _lastFlooredSecondForTimeTic = timeRemaining.floor();
    }
    board.generateFreshBoard();
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

  void _shuffleBoardImpl() {
    board.shuffle();
    overlays.remove('NoMoves');
    _syncIntroInputBlock();
  }

  void _newBoardImpl() {
    board.generateFreshBoard();
    overlays.remove('NoMoves');
    _syncIntroInputBlock();
  }
}
