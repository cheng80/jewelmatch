import 'item_kind.dart';
import 'match_board_models.dart';

class StageRewardGrant {
  const StageRewardGrant({
    required this.item,
    required this.quantity,
    required this.reasonKey,
  });

  final ItemKind item;
  final int quantity;
  final String reasonKey;
}

class StageRewardEvaluator {
  const StageRewardEvaluator._();

  static List<StageRewardGrant> evaluate({
    required MatchBoardGameStats stats,
    required int score,
    required int targetScore,
    required int maxCombo,
    required int remainingHints,
    required int stageStartRemainingHints,
    required bool isClear,
  }) {
    if (!isClear) return const [];

    final grants = <StageRewardGrant>[];
    final targetRatio = targetScore <= 0 ? 1.0 : score / targetScore;

    if (stats.removedGems >= 100 ||
        stats.matchGroups >= 18 ||
        (targetRatio >= 1.12 && stats.removedGems >= 75)) {
      grants.add(
        const StageRewardGrant(
          item: ItemKind.runeHammer,
          quantity: 1,
          reasonKey: 'removedGems',
        ),
      );
    }
    if (maxCombo >= 5 ||
        stats.removedSpecialGems >= 5 ||
        (targetRatio >= 1.18 && maxCombo >= 4)) {
      grants.add(
        const StageRewardGrant(
          item: ItemKind.ancientBomb,
          quantity: 1,
          reasonKey: 'combo',
        ),
      );
    }
    if (stats.specialGemsCreated >= 6 ||
        (targetRatio >= 1.10 &&
            (stats.specialCreatedByKind[GemKind.hyper] ?? 0) >= 1) ||
        (targetRatio >= 1.25 && stats.specialGemsCreated >= 3)) {
      grants.add(
        const StageRewardGrant(
          item: ItemKind.prismTransform,
          quantity: 1,
          reasonKey: 'specialCreated',
        ),
      );
    }
    if (stats.specialGemsActivated >= 4 ||
        (stats.specialActivatedByKind[GemKind.star] ?? 0) >= 2 ||
        (targetRatio >= 1.22 && stats.specialGemsActivated >= 2)) {
      grants.add(
        const StageRewardGrant(
          item: ItemKind.thorHammer,
          quantity: 1,
          reasonKey: 'specialActivated',
        ),
      );
    }
    if (stats.validSwaps > 0 &&
        stats.validSwaps <= 9 &&
        stats.removedGems >= 60) {
      grants.add(
        const StageRewardGrant(
          item: ItemKind.timeSlip,
          quantity: 1,
          reasonKey: 'efficientClear',
        ),
      );
    }
    if (stats.matchGroups >= 24 &&
        (maxCombo >= 4 || stats.specialGemsCreated >= 3)) {
      grants.add(
        const StageRewardGrant(
          item: ItemKind.fateShuffle,
          quantity: 1,
          reasonKey: 'matchGroups',
        ),
      );
    }
    if (remainingHints >= stageStartRemainingHints &&
        stats.validSwaps >= 1 &&
        targetRatio >= 1.15 &&
        maxCombo >= 3) {
      grants.add(
        const StageRewardGrant(
          item: ItemKind.hintPlus,
          quantity: 1,
          reasonKey: 'hintSaved',
        ),
      );
    }
    if ((stats.removedGems >= 160 && maxCombo >= 6) ||
        (targetRatio >= 1.35 &&
            maxCombo >= 5 &&
            stats.specialGemsCreated >= 7)) {
      grants.add(
        const StageRewardGrant(
          item: ItemKind.hyperCube,
          quantity: 1,
          reasonKey: 'highCombo',
        ),
      );
    }
    if (grants.isEmpty) {
      grants.add(
        const StageRewardGrant(
          item: ItemKind.thorHammer,
          quantity: 1,
          reasonKey: 'minimumClear',
        ),
      );
    }

    return _mergeByItem(grants);
  }

  static List<StageRewardGrant> _mergeByItem(List<StageRewardGrant> grants) {
    final order = <ItemKind>[];
    final quantities = <ItemKind, int>{};
    final reasons = <ItemKind, List<String>>{};
    for (final grant in grants) {
      if (!quantities.containsKey(grant.item)) {
        order.add(grant.item);
        reasons[grant.item] = <String>[];
      }
      quantities[grant.item] = (quantities[grant.item] ?? 0) + grant.quantity;
      reasons[grant.item]!.add(grant.reasonKey);
    }
    return [
      for (final item in order)
        StageRewardGrant(
          item: item,
          quantity: quantities[item]!,
          reasonKey: reasons[item]!.join('+'),
        ),
    ];
  }
}
