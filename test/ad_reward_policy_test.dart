import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/ads/ad_refill_limit_backend.dart';
import 'package:stonematch/ads/ad_reward_policy.dart';
import 'package:stonematch/ads/ad_service.dart';
import 'package:stonematch/game/item_inventory.dart';
import 'package:stonematch/game/item_kind.dart';

void main() {
  serverRefillTests();

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

  test('보충 횟수는 기기 시간대가 아니라 KST 자정에 초기화한다', () {
    var now = DateTime.utc(2026, 9, 23, 14, 59, 59);
    final policy = AdRewardPolicy(now: () => now);

    expect(
      policy.grantRefill(
        RunInventory(),
        ItemKind.ancientBomb,
        RewardedAdResult.rewarded,
      ),
      isTrue,
    );
    expect(policy.remainingRefillsToday, 2);

    // UTC 기준으로는 같은 날이지만 KST로는 9월 24일 0시다.
    now = DateTime.utc(2026, 9, 23, 15);
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

class _FakeRefillBackend implements AdRefillLimitBackend {
  AdRefillStatus? statusResult;
  AdRefillStatus? claimResult;
  final claimed = <ItemKind>[];

  @override
  Future<AdRefillStatus?> status() async => statusResult;

  @override
  Future<AdRefillStatus?> claim(ItemKind item) async {
    claimed.add(item);
    return claimResult;
  }
}

void serverRefillTests() {
  group('서버 기준 보충 제한', () {
    test('서버 상태로 오늘 남은 횟수와 하루 제한을 맞춘다', () async {
      final backend = _FakeRefillBackend()
        ..statusResult = const AdRefillStatus(dailyLimit: 5, remaining: 2);
      final policy = AdRewardPolicy(backend: backend);

      await policy.syncRefillStatus();

      expect(policy.dailyRefillLimit, 5);
      expect(policy.remainingRefillsToday, 2);
    });

    test('서버가 지급을 기록하면 보충하고 남은 횟수를 반영한다', () async {
      final backend = _FakeRefillBackend()
        ..claimResult = const AdRefillStatus(
          dailyLimit: 3,
          remaining: 1,
          granted: true,
        );
      final policy = AdRewardPolicy(backend: backend);
      final inventory = RunInventory();

      final granted = await policy.grantRefillVerified(
        inventory,
        ItemKind.runeHammer,
        RewardedAdResult.rewarded,
      );

      expect(granted, isTrue);
      expect(inventory.quantityOf(ItemKind.runeHammer), 1);
      expect(policy.remainingRefillsToday, 1);
      expect(backend.claimed, [ItemKind.runeHammer]);
    });

    test('서버가 오늘 제한을 넘었다고 하면 지급하지 않는다', () async {
      final backend = _FakeRefillBackend()
        ..claimResult = const AdRefillStatus(
          dailyLimit: 3,
          remaining: 0,
          granted: false,
        );
      final policy = AdRewardPolicy(backend: backend);
      final inventory = RunInventory();

      final granted = await policy.grantRefillVerified(
        inventory,
        ItemKind.runeHammer,
        RewardedAdResult.rewarded,
      );

      expect(granted, isFalse);
      expect(inventory.quantityOf(ItemKind.runeHammer), 0);
      expect(policy.remainingRefillsToday, 0);
    });

    test('서버에 닿지 않으면 세션 로컬 제한으로 지급한다', () async {
      final backend = _FakeRefillBackend();
      final policy = AdRewardPolicy(backend: backend);
      final inventory = RunInventory();

      final granted = await policy.grantRefillVerified(
        inventory,
        ItemKind.ancientBomb,
        RewardedAdResult.rewarded,
      );

      expect(granted, isTrue);
      expect(policy.remainingRefillsToday, 2);
    });

    test('광고를 끝까지 보지 않았으면 서버를 부르지 않는다', () async {
      final backend = _FakeRefillBackend();
      final policy = AdRewardPolicy(backend: backend);

      final granted = await policy.grantRefillVerified(
        RunInventory(),
        ItemKind.ancientBomb,
        RewardedAdResult.dismissed,
      );

      expect(granted, isFalse);
      expect(backend.claimed, isEmpty);
    });
  });
}
