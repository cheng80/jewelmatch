import 'dart:math';

import '../../game/jewel_game_mode.dart';
import '../../game/match_board_models.dart';

/// 기록 화면과 배지에 세는 특수 보석 종류.
/// `row`, `col`은 예전 저장 상태 호환용이라 현재 코드가 만들지 않으므로 뺀다.
const List<GemKind> recordedSpecialKinds = [
  GemKind.bomb,
  GemKind.star,
  GemKind.hyper,
  GemKind.supernova,
];

/// 한 판(레벨 모드는 한 스테이지)에서 기록에 반영할 값.
class RoundRecord {
  const RoundRecord({
    required this.mode,
    this.score = 0,
    this.level = 0,
    this.removedGems = 0,
    this.specialsCreated = const {},
    this.hyperSwaps = 0,
    this.maxCombo = 0,
    this.bestMoveScore = 0,
  });

  factory RoundRecord.fromStats(
    MatchBoardGameStats stats, {
    required JewelGameMode mode,
    required int score,
    required int maxCombo,
    int level = 0,
  }) {
    return RoundRecord(
      mode: mode,
      score: score,
      level: level,
      removedGems: stats.removedGems,
      specialsCreated: {
        for (final kind in recordedSpecialKinds)
          kind: stats.specialCreatedByKind[kind] ?? 0,
      },
      hyperSwaps: stats.hyperSwaps,
      maxCombo: maxCombo,
      bestMoveScore: stats.bestMoveScore,
    );
  }

  final JewelGameMode mode;
  final int score;
  final int level;
  final int removedGems;
  final Map<GemKind, int> specialsCreated;
  final int hyperSwaps;
  final int maxCombo;
  final int bestMoveScore;

  /// 같은 스테이지를 두 번 반영할 때(광고 이어하기 뒤 재종료) 누적 값만 차감한다.
  /// 최댓값 항목은 다시 반영해도 결과가 같으므로 그대로 둔다.
  RoundRecord minus(
    RoundRecord? applied, {
    required bool sameScore,
    required bool sameStats,
  }) {
    if (applied == null || (!sameScore && !sameStats)) return this;
    return RoundRecord(
      mode: mode,
      score: sameScore ? max(0, score - applied.score) : score,
      level: level,
      removedGems: sameStats
          ? max(0, removedGems - applied.removedGems)
          : removedGems,
      specialsCreated: sameStats
          ? {
              for (final entry in specialsCreated.entries)
                entry.key: max(
                  0,
                  entry.value - (applied.specialsCreated[entry.key] ?? 0),
                ),
            }
          : specialsCreated,
      hyperSwaps: sameStats
          ? max(0, hyperSwaps - applied.hyperSwaps)
          : hyperSwaps,
      maxCombo: maxCombo,
      bestMoveScore: bestMoveScore,
    );
  }
}

/// 판을 넘어 쌓이는 로컬 기록. 저장 형식은 [toJson]의 `v`로 구분한다.
class PlayerRecords {
  PlayerRecords({
    this.totalScore = 0,
    this.bestMoveScore = 0,
    this.longestCombo = 0,
    this.totalRemovedGems = 0,
    this.hyperSwaps = 0,
    this.bestLevel = 0,
    Map<JewelGameMode, int>? bestScoreByMode,
    Map<GemKind, int>? specialsCreated,
    Map<RecordBadge, int>? badgeTiers,
  }) : bestScoreByMode = bestScoreByMode ?? {},
       specialsCreated = specialsCreated ?? {},
       badgeTiers = badgeTiers ?? {};

  static const int schemaVersion = 1;

  int totalScore;
  int bestMoveScore;
  int longestCombo;
  int totalRemovedGems;
  int hyperSwaps;
  int bestLevel;
  final Map<JewelGameMode, int> bestScoreByMode;
  final Map<GemKind, int> specialsCreated;

  /// 이미 받은 배지 등급. 기준 수치를 나중에 바꿔도 받은 등급은 내려가지 않는다.
  final Map<RecordBadge, int> badgeTiers;

  int get rank => CumulativeRank.rankForScore(totalScore);

  int specialCount(GemKind kind) => specialsCreated[kind] ?? 0;

  int badgeTier(RecordBadge badge) =>
      max(badgeTiers[badge] ?? 0, badge.tierFor(badge.valueOf(this)));

  void apply(RoundRecord round) {
    totalScore += max(0, round.score);
    bestMoveScore = max(bestMoveScore, round.bestMoveScore);
    longestCombo = max(longestCombo, round.maxCombo);
    totalRemovedGems += round.removedGems;
    hyperSwaps += round.hyperSwaps;
    if (round.mode == JewelGameMode.progression) {
      bestLevel = max(bestLevel, round.level);
    }
    bestScoreByMode[round.mode] = max(
      bestScoreByMode[round.mode] ?? 0,
      round.score,
    );
    for (final entry in round.specialsCreated.entries) {
      specialsCreated[entry.key] = specialCount(entry.key) + entry.value;
    }
  }

  Map<String, Object?> toJson() => {
    'v': schemaVersion,
    'totalScore': totalScore,
    'bestMoveScore': bestMoveScore,
    'longestCombo': longestCombo,
    'totalRemovedGems': totalRemovedGems,
    'hyperSwaps': hyperSwaps,
    'bestLevel': bestLevel,
    'bestScoreByMode': {
      for (final e in bestScoreByMode.entries) e.key.name: e.value,
    },
    'specialsCreated': {
      for (final e in specialsCreated.entries) e.key.name: e.value,
    },
    'badges': {for (final e in badgeTiers.entries) e.key.name: e.value},
  };

  /// 모르는 항목은 무시하고, 숫자가 아니거나 음수인 값은 0으로 읽는다.
  /// 형식 자체가 틀리면 [FormatException]을 던져 저장소가 초기화하게 한다.
  factory PlayerRecords.fromJson(Map<String, Object?> json) {
    final version = json['v'];
    if (version is! int || version < 1 || version > schemaVersion) {
      throw FormatException('Unsupported records version: $version');
    }
    int readInt(Object? value) =>
        value is num && value.isFinite ? max(0, value.toInt()) : 0;
    Map<T, int> readMap<T extends Enum>(Object? raw, List<T> values) {
      if (raw is! Map) return {};
      return {
        for (final item in values)
          if (raw[item.name] != null) item: readInt(raw[item.name]),
      };
    }

    return PlayerRecords(
      totalScore: readInt(json['totalScore']),
      bestMoveScore: readInt(json['bestMoveScore']),
      longestCombo: readInt(json['longestCombo']),
      totalRemovedGems: readInt(json['totalRemovedGems']),
      hyperSwaps: readInt(json['hyperSwaps']),
      bestLevel: readInt(json['bestLevel']),
      bestScoreByMode: readMap(json['bestScoreByMode'], JewelGameMode.values),
      specialsCreated: readMap(json['specialsCreated'], recordedSpecialKinds),
      badgeTiers: readMap(
        json['badges'],
        RecordBadge.values,
      ).map((badge, tier) => MapEntry(badge, min(tier, RecordBadge.maxTier))),
    );
  }
}

/// 누적 점수 랭크. 판 안의 레벨 목표를 정하는 `JewelRankProgression`과 별개다.
///
/// 랭크 n에 도달하는 누적 점수는 `5000 × (n² − 1)`이다. 한 단계 폭은
/// `5000 × (2n + 1)`로 점점 넓어진다. 랭크 2는 15,000점(타임 모드 약 2판),
/// 랭크 10은 495,000점, 최고 랭크 50은 12,495,000점이다.
/// ponytail: 플레이테스트 전 시작값. 이벤트 로그로 평균 판 점수를 본 뒤 [unit]만 조정한다.
class CumulativeRank {
  const CumulativeRank._();

  static const int maxRank = 50;
  static const int unit = 5000;

  static int thresholdFor(int rank) {
    final r = rank.clamp(1, maxRank);
    return unit * (r * r - 1);
  }

  static int rankForScore(int totalScore) {
    if (totalScore <= 0) return 1;
    final estimate = sqrt(totalScore / unit + 1).floor().clamp(1, maxRank);
    var rank = estimate;
    while (rank < maxRank && totalScore >= thresholdFor(rank + 1)) {
      rank++;
    }
    while (rank > 1 && totalScore < thresholdFor(rank)) {
      rank--;
    }
    return rank;
  }

  /// 다음 랭크까지 남은 점수. 최고 랭크면 null.
  static int? pointsToNext(int totalScore) {
    final rank = rankForScore(totalScore);
    if (rank >= maxRank) return null;
    return thresholdFor(rank + 1) - max(0, totalScore);
  }
}

/// 배지. 등급은 1 동, 2 은, 3 금, 4 다이아. 0은 아직 없음.
enum RecordBadge {
  bombMaker([10, 50, 200, 1000]),
  starMaker([5, 25, 100, 500]),
  hyperMaker([3, 15, 60, 250]),
  supernovaMaker([1, 5, 20, 100]),
  comboMaster([3, 5, 7, 10]),
  bigMove([3000, 8000, 20000, 50000]),
  timeScore([10000, 20000, 35000, 60000]),
  levelReach([3, 6, 10, 15]),
  gemCollector([1000, 10000, 50000, 200000]),
  annihilator([1, 5, 20, 100]);

  const RecordBadge(this.thresholds);

  static const int maxTier = 4;

  final List<int> thresholds;

  int valueOf(PlayerRecords records) => switch (this) {
    bombMaker => records.specialCount(GemKind.bomb),
    starMaker => records.specialCount(GemKind.star),
    hyperMaker => records.specialCount(GemKind.hyper),
    supernovaMaker => records.specialCount(GemKind.supernova),
    comboMaster => records.longestCombo,
    bigMove => records.bestMoveScore,
    timeScore => records.bestScoreByMode[JewelGameMode.timed] ?? 0,
    levelReach => records.bestLevel,
    gemCollector => records.totalRemovedGems,
    annihilator => records.hyperSwaps,
  };

  int tierFor(int value) {
    var tier = 0;
    while (tier < thresholds.length && value >= thresholds[tier]) {
      tier++;
    }
    return tier;
  }

  /// 다음 등급 기준. 최고 등급이면 null.
  int? nextThreshold(int tier) =>
      tier < thresholds.length ? thresholds[tier] : null;
}

/// 한 번 반영한 결과. 결과 화면 알림에 쓴다.
class RecordsUpdate {
  const RecordsUpdate({
    required this.rankBefore,
    required this.rankAfter,
    this.earnedBadges = const [],
  });

  final int rankBefore;
  final int rankAfter;
  final List<({RecordBadge badge, int tier})> earnedBadges;

  bool get rankedUp => rankAfter > rankBefore;
  bool get isEmpty => !rankedUp && earnedBadges.isEmpty;
}
