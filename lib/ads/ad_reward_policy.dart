import '../game/item_inventory.dart';
import '../game/item_kind.dart';
import 'ad_service.dart';

class AdRewardPolicy {
  AdRewardPolicy({DateTime Function()? now}) : _now = now ?? DateTime.now;

  static const int dailyRefillLimit = 3;

  final DateTime Function() _now;
  final Set<String> _continuedStageAttempts = {};
  DateTime? _refillDate;
  int _refillCount = 0;

  int get remainingRefillsToday {
    _resetRefillCountIfNeeded();
    return dailyRefillLimit - _refillCount;
  }

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

  void _resetRefillCountIfNeeded() {
    final today = _now();
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
