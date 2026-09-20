part of 'match_board_game.dart';

extension MatchBoardGameTiming on MatchBoardGame {
  void _updateTimedModeClock(double dt) {
    if (!hasTimedClock ||
        !isPlaying ||
        timeUp ||
        board.introFillInProgress ||
        hasPendingImmediateItemConfirm ||
        isPrismColorPicking) {
      return;
    }

    timeRemaining -= dt;
    final floored = timeRemaining.floor();
    if (timeRemaining > 0 &&
        floored >= 1 &&
        floored <= MatchBoardGame.timedLowTimeTickMaxSeconds) {
      if (_lastFlooredSecondForTimeTic >= 0 &&
          floored < _lastFlooredSecondForTimeTic) {
        // 10초에서 1초로 갈수록 반음씩 올려 시간 압박을 준다.
        SoundManager.playSfx(
          AssetPaths.sfxTimeTic,
          pitchSemitones: SfxPitch.forLowTimeTick(
            floored,
            fromSeconds: MatchBoardGame.timedLowTimeTickMaxSeconds,
          ),
        );
      }
    }
    _lastFlooredSecondForTimeTic = floored;

    if (timeRemaining <= 0) {
      timeRemaining = 0;
      _triggerTimeUp();
    }
  }

  void _saveBestScoreIfChanged() {
    final score = _scoreForBestSave();
    if (!timeUp && board.state == 'idle' && score != _lastSavedScore) {
      _saveBestRecordIfBetter(score);
      _lastSavedScore = score;
    }
  }

  void _triggerTimeUpImpl() {
    if (!hasTimedClock || timeUp) return;
    timeUp = true;
    isPlaying = false;
    final score = _scoreForBestSave();
    _saveBestRecordIfBetter(score);
    _lastSavedScore = score;
    pauseEngine();
    overlays.add('TimeUp');
    SoundManager.playSfx(AssetPaths.sfxTimeUp);
  }

  void _applyTimedModeTimeBonusImpl(int seconds) {
    if (!hasTimedClock || timeUp || seconds <= 0) return;
    final room = maxTimeSecondsForMode - timeRemaining;
    if (room <= 0) {
      return;
    }
    final applied = min(seconds.toDouble(), room);
    timeRemaining += applied;
    if (_effectPoolsReady) _juiceLayer.onTimeBonus(applied);
  }

  int _scoreForBestSave() {
    return board.score;
  }

  void _saveBestRecordIfBetter(int score) {
    if (isProgressionMode) {
      GameSettings.saveBestProgressionRecordIfBetter(
        level: progressionLevel,
        score: score,
      );
      return;
    }
    GameSettings.saveBestMatchScoreIfBetter(gameMode, score);
  }
}
