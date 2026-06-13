part of 'match_board_game.dart';

extension MatchBoardGameTiming on MatchBoardGame {
  void _updateTimedModeClock(double dt) {
    if (!isTimedMode || !isPlaying || timeUp || board.introFillInProgress) {
      return;
    }

    timeRemaining -= dt;
    final floored = timeRemaining.floor();
    if (timeRemaining > 0 &&
        floored >= 1 &&
        floored <= MatchBoardGame.timedLowTimeTickMaxSeconds) {
      if (_lastFlooredSecondForTimeTic >= 0 &&
          floored < _lastFlooredSecondForTimeTic) {
        SoundManager.playSfx(AssetPaths.sfxTimeTic);
      }
    }
    _lastFlooredSecondForTimeTic = floored;

    if (timeRemaining <= 0) {
      timeRemaining = 0;
      _triggerTimeUp();
    }
  }

  void _saveBestScoreIfChanged() {
    if (!timeUp && board.state == 'idle' && board.score != _lastSavedScore) {
      GameSettings.saveBestMatchScoreIfBetter(gameMode, board.score);
      _lastSavedScore = board.score;
    }
  }

  void _triggerTimeUpImpl() {
    if (!isTimedMode || timeUp) return;
    timeUp = true;
    isPlaying = false;
    GameSettings.saveBestMatchScoreIfBetter(gameMode, board.score);
    _lastSavedScore = board.score;
    pauseEngine();
    overlays.add('TimeUp');
    SoundManager.playSfx(AssetPaths.sfxTimeUp);
  }

  void _applyTimedModeTimeBonusImpl(int seconds) {
    if (!isTimedMode || timeUp || seconds <= 0) return;
    final room = MatchBoardGame.timedMaxTimeSeconds - timeRemaining;
    if (room <= 0) {
      return;
    }
    final applied = min(seconds.toDouble(), room);
    timeRemaining += applied;
  }
}
