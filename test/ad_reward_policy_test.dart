import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/ads/ad_reward_policy.dart';
import 'package:stonematch/ads/ad_service.dart';
import 'package:stonematch/game/item_inventory.dart';
import 'package:stonematch/game/item_kind.dart';

void main() {
  test('이어하기 보상은 스테이지 시도당 한 번만 지급한다', () {
    final policy = AdRewardPolicy();

    expect(policy.grantContinue('1:0', RewardedAdResult.dismissed), isFalse);
    expect(policy.grantContinue('1:0', RewardedAdResult.rewarded), isTrue);
    expect(policy.grantContinue('1:0', RewardedAdResult.rewarded), isFalse);
  });

  test('아이템 보충은 수량 0일 때 하루 세 번만 지급한다', () {
    var now = DateTime(2026, 8, 14);
    final policy = AdRewardPolicy(now: () => now);
    final inventory = RunInventory();
    const items = [
      ItemKind.runeHammer,
      ItemKind.ancientBomb,
      ItemKind.thorHammer,
    ];

    for (final item in items) {
      expect(
        policy.grantRefill(inventory, item, RewardedAdResult.rewarded),
        isTrue,
      );
    }
    expect(policy.remainingRefillsToday, 0);
    expect(
      policy.grantRefill(
        inventory,
        ItemKind.hyperCube,
        RewardedAdResult.rewarded,
      ),
      isFalse,
    );

    now = DateTime(2026, 8, 15);
    expect(policy.remainingRefillsToday, 3);
  });

  test('이미 보유한 아이템과 미완료 광고에는 보충하지 않는다', () {
    final policy = AdRewardPolicy();
    final inventory = RunInventory({ItemKind.runeHammer: 1});

    expect(
      policy.grantRefill(
        inventory,
        ItemKind.runeHammer,
        RewardedAdResult.rewarded,
      ),
      isFalse,
    );
    expect(
      policy.grantRefill(
        inventory,
        ItemKind.ancientBomb,
        RewardedAdResult.dismissed,
      ),
      isFalse,
    );
  });
}
