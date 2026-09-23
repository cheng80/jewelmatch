import 'dart:math';

import 'match_board_models.dart';

/// 레벨 모드 도전 스테이지 목표 종류(Product Spec 6-8).
enum StageChallengeKind {
  /// 지정 색 일반 보석 제거.
  color,

  /// 특수 보석 발동(연쇄 포함).
  special,

  /// 종류 무관 보석 제거.
  gems,
}

/// 도전 스테이지 규칙. 목표 점수(BR-040) 대신 이 목표를 채우면 클리어다.
///
/// 수치는 플레이테스트 전 시작값이다. 조정은 아래 상수만 바꾼다.
class StageChallenge {
  const StageChallenge({required this.kind, required this.target, this.color});

  /// 이 배수 레벨이 도전 스테이지다.
  static const int levelInterval = 4;

  static const int colorBase = 15;
  static const int colorPerStep = 5;
  static const int colorMax = 60;
  static const int specialBase = 2;
  static const int specialPerStep = 1;
  static const int specialMax = 10;
  static const int gemsBase = 60;
  static const int gemsPerStep = 15;
  static const int gemsMax = 200;

  final StageChallengeKind kind;
  final int target;

  /// [StageChallengeKind.color]일 때만 쓰는 1부터 시작하는 보석 색.
  final int? color;

  /// 도전 스테이지가 아니면 null. 같은 레벨은 항상 같은 목표다.
  static StageChallenge? forLevel(int level, {int colorCount = 6}) {
    if (level < levelInterval || level % levelInterval != 0) return null;
    final k = level ~/ levelInterval;
    switch (k % 3) {
      case 1:
        return StageChallenge(
          kind: StageChallengeKind.color,
          target: min(colorBase + colorPerStep * k, colorMax),
          // 색 목표 순번(k = 1, 4, 7, ...)마다 다음 색으로 돈다.
          color: ((k - 1) ~/ 3) % colorCount + 1,
        );
      case 2:
        return StageChallenge(
          kind: StageChallengeKind.special,
          target: min(specialBase + specialPerStep * k, specialMax),
        );
      default:
        return StageChallenge(
          kind: StageChallengeKind.gems,
          target: min(gemsBase + gemsPerStep * k, gemsMax),
        );
    }
  }

  /// 현재 판 통계 기준 진행도. [target]을 넘지 않는다.
  int progress(MatchBoardGameStats stats) {
    final value = switch (kind) {
      StageChallengeKind.color => stats.removedNormalByColor[color] ?? 0,
      StageChallengeKind.special => stats.specialGemsActivated,
      StageChallengeKind.gems => stats.removedGems,
    };
    return min(value, target);
  }

  bool isComplete(MatchBoardGameStats stats) => progress(stats) >= target;
}
