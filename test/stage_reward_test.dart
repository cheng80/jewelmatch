import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/game/item_kind.dart';
import 'package:stonematch/game/match_board_models.dart';
import 'package:stonematch/game/stage_reward.dart';

void main() {
  test('low score clear grants thor hammer as minimum reward', () {
    final rewards = StageRewardEvaluator.evaluate(
      stats: MatchBoardGameStats(),
      score: 7500,
      targetScore: 7500,
      maxCombo: 1,
      remainingHints: 0,
      stageStartRemainingHints: 0,
      isClear: true,
    );

    expect(rewards, hasLength(1));
    expect(rewards.single.item, ItemKind.thorHammer);
    expect(rewards.single.quantity, 1);
    expect(rewards.single.reasonKey, 'minimumClear');
  });

  test('high score alone still falls back to minimum thor reward', () {
    final rewards = StageRewardEvaluator.evaluate(
      stats: MatchBoardGameStats(),
      score: 50000,
      targetScore: 7500,
      maxCombo: 1,
      remainingHints: 0,
      stageStartRemainingHints: 0,
      isClear: true,
    );

    expect(rewards, hasLength(1));
    expect(rewards.single.item, ItemKind.thorHammer);
    expect(rewards.single.reasonKey, 'minimumClear');
  });

  test('target over-score needs supporting performance stats for rewards', () {
    final stats = MatchBoardGameStats()
      ..removedGems = 61
      ..specialGemsCreated = 2;

    final rewards = StageRewardEvaluator.evaluate(
      stats: stats,
      score: 9000,
      targetScore: 7500,
      maxCombo: 1,
      remainingHints: 0,
      stageStartRemainingHints: 0,
      isClear: true,
    );

    expect(rewards.map((reward) => reward.item), contains(ItemKind.runeHammer));
    expect(
      rewards.map((reward) => reward.item),
      contains(ItemKind.prismTransform),
    );
    expect(
      rewards.map((reward) => reward.item),
      isNot(contains(ItemKind.thorHammer)),
    );
  });

  test('reward evaluator grants every matched item without max count cap', () {
    final stats = MatchBoardGameStats()
      ..validSwaps = 10
      ..matchGroups = 20
      ..removedGems = 130
      ..specialGemsCreated = 4
      ..specialGemsActivated = 2;
    stats.removedByKind[GemKind.bomb] = 3;
    stats.specialCreatedByKind[GemKind.hyper] = 1;
    stats.specialActivatedByKind[GemKind.star] = 1;

    final rewards = StageRewardEvaluator.evaluate(
      stats: stats,
      score: 130000,
      targetScore: 100000,
      maxCombo: 5,
      remainingHints: 2,
      stageStartRemainingHints: 2,
      isClear: true,
    );

    expect(rewards.map((reward) => reward.item), contains(ItemKind.thorHammer));
    expect(rewards.map((reward) => reward.item), contains(ItemKind.runeHammer));
    expect(
      rewards.map((reward) => reward.item),
      contains(ItemKind.ancientBomb),
    );
    expect(
      rewards.map((reward) => reward.item),
      contains(ItemKind.prismTransform),
    );
    expect(rewards.map((reward) => reward.item), contains(ItemKind.timeSlip));
    expect(
      rewards.map((reward) => reward.item),
      contains(ItemKind.fateShuffle),
    );
    expect(rewards.map((reward) => reward.item), contains(ItemKind.hintPlus));
    expect(rewards.map((reward) => reward.item), contains(ItemKind.hyperCube));
    expect(rewards.length, greaterThan(2));
    expect(
      rewards
          .singleWhere((reward) => reward.item == ItemKind.thorHammer)
          .quantity,
      1,
    );
  });

  test('failed stage grants no rewards', () {
    final rewards = StageRewardEvaluator.evaluate(
      stats: MatchBoardGameStats(),
      score: 999999,
      targetScore: 7500,
      maxCombo: 9,
      remainingHints: 9,
      stageStartRemainingHints: 9,
      isClear: false,
    );

    expect(rewards, isEmpty);
  });
}
