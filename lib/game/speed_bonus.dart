import 'dart:math' show max, min;

/// 타임 모드 Speed Bonus 규칙 (Product Spec 6-3, PLAN-005 1b, D5).
///
/// 유저의 유효 스왑만 센다. 연쇄 단계, 아이템, 특수 보석 탭은 호출하지 않는다.
/// 시계는 [advance]로만 흐르므로 게임이 멈춘 동안에는 간격이 늘지 않는다.
class SpeedBonus {
  SpeedBonus({required this.enabled});

  /// 직전 유효 스왑과의 간격이 이 안이면 빠른 매치로 이어진다.
  /// Blitz 3초 + 한 번의 매치 해소 연출(안착 0.12, 제거 0.18, 낙하 0.11,
  /// 보충 0.11, 확인 0.09 = 0.61초) 중 입력을 못 받는 앞부분 약 0.5초.
  static const double windowSeconds = 3.5;

  /// 이어진 스왑이 이 수에 닿으면 첫 보너스가 붙는다.
  static const int startChain = 3;
  static const int startBonus = 200;
  static const int stepBonus = 100;
  static const int maxBonus = 1000;
  static const int maxTier = (maxBonus - startBonus) ~/ stepBonus + 1;

  final bool enabled;

  double _clock = 0;
  double? _lastSwapAt;
  int _chain = 0;
  int _tier = 0;
  int peakTier = 0;
  int totalBonus = 0;

  /// 현재 단계(0이면 비활성, 1이면 +200, [maxTier]이면 +1000).
  int get tier => _tier;
  int get currentBonus => bonusForTier(_tier);

  static int bonusForTier(int tier) =>
      tier <= 0 ? 0 : min(maxBonus, startBonus + (tier - 1) * stepBonus);

  void advance(double dt) {
    if (!enabled || dt <= 0) return;
    _clock += dt;
    final last = _lastSwapAt;
    if (last != null && _clock - last > windowSeconds) {
      _chain = 0;
      _tier = 0;
    }
  }

  /// 유효 스왑이 확정된 순간 한 번 호출한다. 더할 점수를 돌려준다.
  int onValidSwap() {
    if (!enabled) return 0;
    final last = _lastSwapAt;
    _chain = last != null && _clock - last <= windowSeconds ? _chain + 1 : 1;
    _lastSwapAt = _clock;
    _tier = max(0, min(maxTier, _chain - startChain + 1));
    peakTier = max(peakTier, _tier);
    final bonus = bonusForTier(_tier);
    totalBonus += bonus;
    return bonus;
  }

  void reset() {
    _clock = 0;
    _lastSwapAt = null;
    _chain = 0;
    _tier = 0;
    peakTier = 0;
    totalBonus = 0;
  }
}
