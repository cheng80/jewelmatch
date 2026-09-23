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

    speedBonus.advance(dt);
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

  /// 시간 0. 타임 모드는 남은 특수 보석이 있으면 Last Hurrah를 먼저 끝낸다(D6).
  /// 레벨 모드와 특수 보석이 없는 보드는 바로 판을 끝낸다.
  void _triggerTimeUpImpl() {
    if (!hasTimedClock || timeUp || lastHurrahActive) return;
    if (!isTimedMode || !LastHurrah.hasSpecial(board)) {
      _finalizeRound();
      return;
    }
    isPlaying = false;
    board
      ..clearHint()
      ..cancelPendingHyperTap()
      ..selected = null;
    _lastHurrah = LastHurrah(board, random: lastHurrahRandom);
    final reducedMotion = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    if (reducedMotion) {
      _completeLastHurrah(instant: true);
      return;
    }
    _speedBonusBadge.hide();
    if (_lastHurrahBadge.isMounted) _lastHurrahBadge.show();
  }

  void _updateLastHurrah(double dt) {
    final run = _lastHurrah;
    if (run == null) return;
    run.update(dt);
    if (run.done) _completeLastHurrah();
  }

  /// [instant]면 남은 발동을 연출 없이 계산한다(reduced motion, 백그라운드 전환).
  void _completeLastHurrah({bool instant = false}) {
    final run = _lastHurrah;
    if (run == null) return;
    if (instant) run.finishInstantly();
    _lastHurrah = null;
    _lastHurrahBadge.hide();
    // 실제로 발동한 마무리만 남긴다(시간 0 순간 유저 연쇄가 특수 보석을 모두 지운 경우 제외).
    if (run.activations > 0) {
      EventLogger.instance.log('last_hurrah', run.eventParams);
    }
    _finalizeRound();
  }

  /// 판 종료 확정 지점. 타임 모드는 Last Hurrah 뒤 최종 점수로 한 번 온다.
  /// 기록 저장, round_end, TimeUp 결과(진입 시 랭킹 제출)가 여기서 시작한다.
  void _finalizeRound() {
    if (timeUp) return;
    timeUp = true;
    isPlaying = false;
    final score = _scoreForBestSave();
    _saveBestRecordIfBetter(score);
    _lastSavedScore = score;
    logRoundEnd('time_up');
    pauseEngine();
    overlays.add('TimeUp');
    SoundManager.playSfx(AssetPaths.sfxTimeUp);
  }

  void _applyTimedModeTimeBonusImpl(int seconds) {
    // Last Hurrah 중에는 시간 보상이 없다.
    if (!hasTimedClock || timeUp || lastHurrahActive || seconds <= 0) return;
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
