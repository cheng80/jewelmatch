import 'package:flutter_test/flutter_test.dart';
import 'package:jewelmatch/game/jewel_rank_progression.dart';
import 'package:jewelmatch/game/match_board_models.dart';

void main() {
  test('levelForXp follows 250k growing thresholds', () {
    expect(JewelRankProgression.levelForXp(0), 1);
    expect(JewelRankProgression.levelForXp(249999), 1);
    expect(JewelRankProgression.levelForXp(250000), 2);
    expect(JewelRankProgression.levelForXp(749999), 2);
    expect(JewelRankProgression.levelForXp(750000), 3);
  });

  test('xpFromScore scales Jewel Match scoring to rank XP', () {
    expect(JewelRankProgression.xpFromScore(2500), 250000);
  });

  test('progressRatio measures current level XP window', () {
    expect(
      JewelRankProgression.progressRatio(level: 2, xp: 500000),
      closeTo(0.5, 0.001),
    );
    expect(
      JewelRankProgression.progressRatio(level: 2, xp: 750000),
      closeTo(1.0, 0.001),
    );
  });

  test('scoreTargetForLevel follows per-stage Blitz rank increments', () {
    expect(JewelRankProgression.scoreTargetForLevel(1), 7500);
    expect(JewelRankProgression.scoreTargetForLevel(2), 15000);
    expect(JewelRankProgression.scoreTargetForLevel(3), 22500);
    expect(JewelRankProgression.scoreTargetForLevel(4), 30000);
  });

  test('levelForScore follows scaled score targets', () {
    expect(JewelRankProgression.levelForScore(7499), 1);
    expect(JewelRankProgression.levelForScore(7500), 2);
    expect(JewelRankProgression.levelForScore(14999), 2);
    expect(JewelRankProgression.levelForScore(15000), 3);
  });

  test('stageProgressRatio measures the current stage score target', () {
    expect(
      JewelRankProgression.stageProgressRatio(level: 2, score: 7500),
      closeTo(0.5, 0.001),
    );
    expect(
      JewelRankProgression.stageProgressRatio(level: 2, score: 15000),
      closeTo(1.0, 0.001),
    );
  });

  test('formatCompactScore is available for cramped score layouts', () {
    expect(JewelRankProgression.formatCompactScore(9999), '9,999');
    expect(JewelRankProgression.formatCompactScore(10000), '10K');
    expect(JewelRankProgression.formatCompactScore(112500), '112K');
    expect(JewelRankProgression.formatCompactScore(1250000), '1.2M');
    expect(JewelRankProgression.formatCompactScore(3400000000), '3.4B');
  });

  test('bonus kinds scale with previous level performance', () {
    expect(JewelProgressionBonus.kindsForNextLevel(maxCombo: 1, nextLevel: 2), [
      GemKind.bomb,
    ]);
    expect(JewelProgressionBonus.kindsForNextLevel(maxCombo: 3, nextLevel: 2), [
      GemKind.bomb,
      GemKind.star,
    ]);
    expect(JewelProgressionBonus.kindsForNextLevel(maxCombo: 5, nextLevel: 2), [
      GemKind.bomb,
      GemKind.star,
      GemKind.hyper,
    ]);
    expect(JewelProgressionBonus.kindsForNextLevel(maxCombo: 1, nextLevel: 5), [
      GemKind.bomb,
      GemKind.hyper,
    ]);
  });
}
