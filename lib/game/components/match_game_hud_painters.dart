part of 'match_game_hud.dart';

extension _MatchGameHudPainterCache on MatchGameHud {
  void _rebuildStaticPainters() {
    final t = game.hudTextScale;
    _scoreLabel = TextPainter(
      text: TextSpan(
        text: game.localeString('score', 'Score'),
        style: _ts(
          size: 14 * t,
          color: JewelCandyLuminaTheme.tertiaryGold.withValues(alpha: 0.92),
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    final isTimedMode = game.isTimedMode;
    final top1Name = game.rankingTop1Name;
    final top1Score = game.rankingTop1Score;
    final best = _cachedBest;
    final bestProgressionLevel = _cachedBestProgressionLevel;
    _cachedRankingTop1Name = top1Name;
    _cachedRankingTop1Score = top1Score;

    String bestLabelText;
    String bestValueText;
    if (isTimedMode && top1Name != null && top1Score != null) {
      bestValueText = _fmt.format(top1Score);
      _bestLabel = TextPainter(
        text: TextSpan(
          text: top1Name,
          style: _ts(
            size: 12 * t,
            color: JewelCandyLuminaTheme.secondaryCyan.withValues(alpha: 0.95),
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
    } else {
      final bestPrefix = game.localeString('bestScore', 'Best');
      bestLabelText = game.isProgressionMode && bestProgressionLevel != null
          ? '$bestPrefix : ${game.localeString('levelLabel', 'Level')}$bestProgressionLevel'
          : bestPrefix;
      bestValueText = best != null ? _fmt.format(best) : '—';
      _bestLabel = TextPainter(
        text: TextSpan(
          text: bestLabelText,
          style: _ts(
            size: 12 * t,
            color: JewelCandyLuminaTheme.secondaryCyan.withValues(alpha: 0.95),
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
    }

    _bestValue = TextPainter(
      text: TextSpan(
        text: bestValueText,
        style: _ts(
          size: 17 * t,
          color: JewelCandyLuminaTheme.goldStrong,
          weight: FontWeight.bold,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    _rebuildTimeBarText();
    _rebuildComboPainters();
    _rebuildScoreValue();
  }

  void _rebuildTimeBarText() {
    final t = game.hudTextScale;
    _cachedTimedModeForText = game.hasTimedClock;
    if (game.hasTimedClock) {
      final s = game.timeRemaining.ceil().clamp(0, 99999);
      _cachedTimedSeconds = s;
      final m = s ~/ 60;
      final r = s % 60;
      final timeText = '$m:${r.toString().padLeft(2, '0')}';
      final txt = game.isProgressionMode
          ? '${game.progressionLabel()}  $timeText'
          : timeText;
      _cachedProgressionXp = game.isProgressionMode
          ? game.progressionLevel
          : null;
      // 밝은 그라데이션 위에서도 읽히도록: 밝은 글자 + 짙은 외곽 그림자(시안 단색은 대비 부족)
      final critical = s <= 10;
      final baseSh = _hudLegibilityShadows();
      _timeInBar = TextPainter(
        text: TextSpan(
          text: txt,
          style: _ts(
            size: (game.isProgressionMode ? 12 : 19) * t,
            color: critical ? const Color(0xFFFFEB3B) : const Color(0xFFFFFDE7),
            weight: FontWeight.w800,
            shadows: critical
                ? [
                    Shadow(
                      color: Colors.red.shade900.withValues(alpha: 0.9),
                      offset: const Offset(0, 1),
                      blurRadius: 4,
                    ),
                    ...baseSh,
                  ]
                : baseSh,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: game.safeContentWidth * 0.86);
    } else {
      _cachedTimedSeconds = null;
      _cachedProgressionXp = null;
      _timeInBar = TextPainter(
        text: TextSpan(
          text: game.localeString('unlimitedMode', 'Untimed'),
          style: _ts(
            size: 15 * t,
            color: JewelCandyLuminaTheme.primaryPink.withValues(alpha: 0.95),
            weight: FontWeight.w600,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
    }
  }

  int _displayCurrentCombo() {
    final s = game.board.state;
    if (s != 'idle' && s != 'gameover') {
      return game.board.combo;
    }
    return game.board.lastCombo;
  }

  void _rebuildComboPainters() {
    final t = game.hudTextScale;
    final cur = _displayCurrentCombo();
    final mx = game.board.maxCombo;
    _cachedDisplayedCombo = cur;
    _cachedMaxCombo = mx;
    final sh = _hudLegibilityShadows();

    _comboLeftLabel = TextPainter(
      text: TextSpan(
        text: game.localeString('combo', 'Combo'),
        style: _ts(
          size: 16 * t,
          color: const Color(0xFFFFFDE7),
          weight: FontWeight.w600,
          shadows: sh,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    _comboLeftValue = TextPainter(
      text: TextSpan(
        text: '×$cur',
        style: _ts(
          size: 30 * t,
          color: JewelCandyLuminaTheme.secondaryCyan,
          weight: FontWeight.w800,
          shadows: sh,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    _comboRightLabel = TextPainter(
      text: TextSpan(
        text: game.localeString('maxComboLabel', 'Max'),
        style: _ts(
          size: 16 * t,
          color: const Color(0xFFFFFDE7),
          weight: FontWeight.w600,
          shadows: sh,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    _comboRightValue = TextPainter(
      text: TextSpan(
        text: '×$mx',
        style: _ts(
          size: 30 * t,
          color: JewelCandyLuminaTheme.goldStrong,
          weight: FontWeight.w800,
          shadows: sh,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
  }

  void _rebuildScoreValue() {
    final t = game.hudTextScale;
    _cachedScore = game.board.score;
    _scoreLabel = TextPainter(
      text: TextSpan(
        text: game.isProgressionMode
            ? '${game.localeString('levelLabel', 'Lv.')} ${game.progressionLevel}'
            : game.localeString('score', 'Score'),
        style: _ts(
          size: 14 * t,
          color: JewelCandyLuminaTheme.tertiaryGold.withValues(alpha: 0.92),
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    final scoreText = game.isProgressionMode
        ? '${_fmt.format(game.board.score)}\n'
              '${game.localeString('targetScore', 'Target')} '
              '${_fmt.format(game.progressionTargetScore)}'
        : _fmt.format(_cachedScore);
    _scoreValue = TextPainter(
      text: TextSpan(
        text: scoreText,
        style: _ts(
          size: (game.isProgressionMode ? 29 : 40) * t,
          color: const Color(0xFFFFFDE7),
          weight: FontWeight.bold,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: game.safeContentWidth * 0.9);
    if (game.isProgressionMode) _rebuildTimeBarText();
  }
}
