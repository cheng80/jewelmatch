// 소리의 "의미"(콤보 단계, 매치 크기, 남은 시간)를 반음 수로 바꾸는 한 곳.
// 호출부는 반음 수만 넘기고, 재생 속도 변환과 플랫폼 분기는 SoundManager가 한다.

import 'dart:math' as math;

/// 매치 크기 등급. 매치를 만든 특수 보석 종류와 1:1이다.
/// 반음은 커질수록 밝게 들리도록 올린다(재생 속도도 함께 빨라져 4슬롯이 빨리 빈다).
enum MatchSfxTier {
  /// 4개 매치(bomb 생성).
  match4(0),

  /// T/L 교차 매치(star 생성).
  matchTL(2),

  /// 5개 직선 매치(hyper 생성).
  match5(3),

  /// 6개 이상 직선 매치(supernova 생성).
  match6plus(5);

  const MatchSfxTier(this.semitones);

  final int semitones;
}

class SfxPitch {
  SfxPitch._();

  /// 네이티브 `audioplayers`의 `setPlaybackRate`가 피치까지 바꾸는지 미확인(R2).
  /// 속도만 빨라지고 피치가 그대로면 어색하므로 실기기에서 확인할 때까지 끈다.
  /// 확인 뒤에는 여기 한 곳만 true로 바꾼다.
  static const bool nativePitchEnabled = false;

  /// 반음 = 2^(1/12).
  static const double semitoneRatio = 1.0594630943592953;

  /// 콤보 상승 상한. 8반음(장6도)을 넘으면 원래 소리로 안 들린다.
  static const int maxComboSemitones = 8;

  /// 전체 상한. 한 옥타브.
  static const int maxSemitones = 12;

  /// 콤보 n단계 → 반음. 1단계가 원래 음이고 단계마다 반음씩 오른다.
  static int forCombo(int combo) => (combo - 1).clamp(0, maxComboSemitones);

  /// 매치 계열 SFX의 반음. 매치 크기 등급 위에 콤보 상승을 얹는다.
  static int forMatch(MatchSfxTier tier, int combo) =>
      (tier.semitones + forCombo(combo)).clamp(0, maxSemitones);

  /// 저시간 틱. [fromSeconds]에서 시작해 1초로 갈수록 반음씩 오른다.
  static int forLowTimeTick(int secondsLeft, {required int fromSeconds}) =>
      (fromSeconds - secondsLeft).clamp(0, maxSemitones);

  static double playbackRate(int semitones, {required bool isWeb}) =>
      isWeb || nativePitchEnabled ? rateForSemitones(semitones) : 1.0;

  /// 반음 → 재생 속도 배율.
  static double rateForSemitones(int semitones) {
    if (semitones == 0) return 1.0;
    final clamped = semitones.clamp(-maxSemitones, maxSemitones);
    return math.pow(semitoneRatio, clamped).toDouble();
  }
}

/// 이번 제거 단계에서 새로 태어난 특수 보석으로 매치 모양을 읽는다.
/// 제거 콜백에는 매치 그룹 정보가 없고, 누적 생성 카운터만 공개되어 있어 증분으로 본다.
class MatchSfxTierTracker {
  final Expando<MatchSfxTierTracker> _owners = Expando();
  int _star = 0;
  int _hyper = 0;
  int _supernova = 0;

  /// 누적 생성 수를 넘기면 직전 호출 이후 늘어난 종류로 등급을 고른다.
  /// 카운터가 줄면(새 판) 그대로 따라가고 기본 등급을 돌려준다.
  MatchSfxTier read({
    Object? owner,
    int star = 0,
    int hyper = 0,
    int supernova = 0,
  }) {
    if (owner != null) {
      final tracker = _owners[owner] ??= MatchSfxTierTracker();
      return tracker.read(star: star, hyper: hyper, supernova: supernova);
    }
    final MatchSfxTier tier;
    if (supernova > _supernova) {
      tier = MatchSfxTier.match6plus;
    } else if (hyper > _hyper) {
      tier = MatchSfxTier.match5;
    } else if (star > _star) {
      tier = MatchSfxTier.matchTL;
    } else {
      tier = MatchSfxTier.match4;
    }
    _star = star;
    _hyper = hyper;
    _supernova = supernova;
    return tier;
  }
}

/// 보드 통계 객체별 약한 참조로 수명을 분리한다. 새 판과 동시 보드가 간섭하지 않는다.
final MatchSfxTierTracker matchSfxTierTracker = MatchSfxTierTracker();
