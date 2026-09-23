import '../game/item_inventory.dart';
import '../game/item_kind.dart';
import 'ad_refill_limit_backend.dart';
import 'ad_service.dart';

/// 보충 광고 지급 결과. 화면 문구와 이벤트 기록이 거절 이유를 구분하는 데 쓴다.
enum RefillGrantOutcome {
  /// 아이템 1개를 지급했다.
  granted,

  /// 광고를 끝까지 보지 않았다.
  adNotCompleted,

  /// 오늘 보충 횟수를 모두 썼다(로컬 또는 서버 판정).
  limitReached,

  /// 그 밖의 이유로 지급하지 않았다(이미 가진 아이템, 서버 거절).
  rejected,
}

class AdRewardPolicy {
  AdRewardPolicy({DateTime Function()? now, AdRefillLimitBackend? backend})
    : _now = now ?? DateTime.now,
      _backend = backend;

  /// 서버 응답이 없을 때 쓰는 기본 하루 제한(BR-103).
  static const int defaultDailyRefillLimit = 3;

  final DateTime Function() _now;
  final AdRefillLimitBackend? _backend;
  final Set<String> _continuedStageAttempts = {};
  DateTime? _refillDate;
  int _refillCount = 0;
  int _dailyRefillLimit = defaultDailyRefillLimit;

  int get dailyRefillLimit => _dailyRefillLimit;

  int get remainingRefillsToday {
    _resetRefillCountIfNeeded();
    return (_dailyRefillLimit - _refillCount).clamp(0, _dailyRefillLimit);
  }

  bool get isRefillLimitReached => remainingRefillsToday <= 0;

  bool canContinueStage(String attemptId) =>
      !_continuedStageAttempts.contains(attemptId);

  bool grantContinue(String attemptId, RewardedAdResult result) {
    if (result != RewardedAdResult.rewarded || !canContinueStage(attemptId)) {
      return false;
    }
    _continuedStageAttempts.add(attemptId);
    return true;
  }

  bool canRefill(RunInventory inventory, ItemKind item) =>
      inventory.quantityOf(item) == 0 && remainingRefillsToday > 0;

  bool grantRefill(
    RunInventory inventory,
    ItemKind item,
    RewardedAdResult result,
  ) {
    if (result != RewardedAdResult.rewarded || !canRefill(inventory, item)) {
      return false;
    }
    inventory.add(item);
    _refillCount += 1;
    return true;
  }

  /// 서버의 오늘 사용 횟수와 제한으로 로컬 값을 맞춘다. 실패하면 로컬 값을 유지한다.
  Future<void> syncRefillStatus() async {
    final backend = _backend;
    if (backend == null) return;
    final status = await backend.status();
    if (status != null) _applyServerStatus(status);
  }

  /// 보상형 광고 완료 후 서버에 지급을 기록하고 결과에 따라 보충한다.
  /// 서버가 제한 초과라고 답하면 지급하지 않는다. 서버에 닿지 못하면 세션 로컬 제한으로 판단한다.
  Future<RefillGrantOutcome> grantRefillVerified(
    RunInventory inventory,
    ItemKind item,
    RewardedAdResult result,
  ) async {
    if (result != RewardedAdResult.rewarded) {
      return RefillGrantOutcome.adNotCompleted;
    }
    if (isRefillLimitReached) return RefillGrantOutcome.limitReached;
    if (!canRefill(inventory, item)) return RefillGrantOutcome.rejected;
    final backend = _backend;
    if (backend != null) {
      final status = await backend.claim(item);
      if (status != null) {
        _applyServerStatus(status);
        if (status.granted != true) {
          return status.remaining <= 0
              ? RefillGrantOutcome.limitReached
              : RefillGrantOutcome.rejected;
        }
        if (inventory.quantityOf(item) != 0) return RefillGrantOutcome.rejected;
        inventory.add(item);
        return RefillGrantOutcome.granted;
      }
    }
    return grantRefill(inventory, item, result)
        ? RefillGrantOutcome.granted
        : RefillGrantOutcome.rejected;
  }

  void _applyServerStatus(AdRefillStatus status) {
    _resetRefillCountIfNeeded();
    final limit = status.dailyLimit.clamp(0, 20);
    _dailyRefillLimit = limit;
    _refillCount = (limit - status.remaining).clamp(0, limit);
  }

  /// 서버와 같은 KST(UTC+9) 날짜로 하루를 나눈다.
  void _resetRefillCountIfNeeded() {
    final today = _now().toUtc().add(const Duration(hours: 9));
    final refillDate = _refillDate;
    if (refillDate == null ||
        refillDate.year != today.year ||
        refillDate.month != today.month ||
        refillDate.day != today.day) {
      _refillDate = today;
      _refillCount = 0;
    }
  }
}
