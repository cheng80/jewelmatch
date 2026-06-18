import 'package:intl/intl.dart';

import 'match_board_models.dart';

/// 누적 XP 기반 클래식 진행 모드 규칙.
class JewelRankProgression {
  const JewelRankProgression._();

  static final NumberFormat _fmt = NumberFormat.decimalPattern();

  static const int xpStep = 250000;
  static const int scoreToXpScale = 100;
  static const int scoreTargetScale = 3;
  static const int relaxedStageStartLevel = 6;
  static const int relaxedScoreIncrement = 5000;

  static int xpFromScore(int score) => score * scoreToXpScale;
  static int scoreTargetForLevel(int level) {
    final linearTarget =
        (xpNeededForNextLevel(level) ~/ scoreToXpScale) * scoreTargetScale;
    if (level < relaxedStageStartLevel) return linearTarget;

    final levelFiveTarget =
        (xpNeededForNextLevel(relaxedStageStartLevel - 1) ~/ scoreToXpScale) *
        scoreTargetScale;
    return levelFiveTarget +
        (level - relaxedStageStartLevel + 1) * relaxedScoreIncrement;
  }

  static String formatCompactScore(int score) {
    if (score < 10000) return _fmt.format(score);
    const units = [
      (value: 1000000000000, suffix: 'T'),
      (value: 1000000000, suffix: 'B'),
      (value: 1000000, suffix: 'M'),
      (value: 1000, suffix: 'K'),
    ];
    for (final unit in units) {
      if (score >= unit.value) {
        final scaled = score / unit.value;
        final truncated = (scaled * 10).floor() / 10;
        final text = scaled >= 10
            ? scaled.floor().toString()
            : truncated.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
        return '$text${unit.suffix}';
      }
    }
    return _fmt.format(score);
  }

  static int levelForXp(int xp) {
    if (xp < xpStep) return 1;
    var level = 1;
    var nextTotal = xpStep;
    while (xp >= nextTotal) {
      level++;
      nextTotal += xpNeededForNextLevel(level);
    }
    return level;
  }

  static int levelForScore(int score) {
    var level = 1;
    while (score >= scoreTargetForLevel(level)) {
      level++;
    }
    return level;
  }

  static double stageProgressRatio({required int level, required int score}) {
    final target = scoreTargetForLevel(level);
    if (target <= 0) return 0;
    return (score / target).clamp(0.0, 1.0);
  }

  static int xpNeededForNextLevel(int level) => level * xpStep;

  static int totalXpRequiredForLevel(int level) {
    if (level <= 1) return 0;
    return xpStep * (level - 1) * level ~/ 2;
  }

  static int nextLevelTotalXp(int level) =>
      totalXpRequiredForLevel(level) + xpNeededForNextLevel(level);

  static double progressRatio({required int level, required int xp}) {
    final start = totalXpRequiredForLevel(level);
    final needed = xpNeededForNextLevel(level);
    if (needed <= 0) return 0;
    return ((xp - start) / needed).clamp(0.0, 1.0);
  }
}

class JewelRankView {
  JewelRankView({required this.level, required this.xp})
    : targetXp = JewelRankProgression.nextLevelTotalXp(level),
      progressRatio = JewelRankProgression.progressRatio(level: level, xp: xp);

  static final NumberFormat _fmt = NumberFormat.decimalPattern();

  final int level;
  final int xp;
  final int targetXp;
  final double progressRatio;

  String label(String levelLabel, String xpLabel) =>
      '$levelLabel $level  ${_fmt.format(xp)} / '
      '${_fmt.format(targetXp)} $xpLabel';

  String timeBarLabel(String levelLabel) => '$levelLabel $level';
}

class JewelProgressionBonus {
  const JewelProgressionBonus._();

  static List<GemKind> kindsForNextLevel({
    required int maxCombo,
    required int nextLevel,
  }) {
    final kinds = <GemKind>[GemKind.bomb];
    if (maxCombo >= 3) {
      kinds.add(GemKind.star);
    }
    if (maxCombo >= 5 || nextLevel % 5 == 0) {
      kinds.add(GemKind.hyper);
    }
    return List<GemKind>.unmodifiable(kinds.take(3));
  }
}
