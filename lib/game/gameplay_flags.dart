/// 실험 기능 스위치. 나중에 플레이 판단으로 켜고 끄기 위해 원격 설정과 URL로 바꿀 수 있다.
///
/// 기본값은 모두 기존 동작이다. 판마다 판 시작 때 [current]를 한 번 읽어 판 도중에는 바뀌지 않는다.
/// 원격 키는 Supabase `app_config`의 `gameplay`, 웹 URL은 `?exp=`(예: `?exp=t1,tg,mg,c7:10,nolhc`, `?exp=none`).
class GameplayFlags {
  const GameplayFlags({
    this.timeRewardT1 = false,
    this.timeGem = false,
    this.multiplierGem = false,
    this.seventhColorFromLevel,
    this.lastHurrahComboMultiplier = true,
  });

  /// T1(D7): 타임 모드에서 3개 매치 단독 단계는 시간 보상 0초. 4개 이상, 특수 보석 생성이나 발동, 콤보 2 이상 단계만 시간을 준다.
  final bool timeRewardT1;

  /// T2: 타임 모드 Time 보석(+5초). 큰 한 수에서 생기고 지우면 시간을 얻는다.
  final bool timeGem;

  /// Blitz식 Multiplier 보석(타임 모드). 지우면 판 점수 배율이 오른다(최대 ×8).
  final bool multiplierGem;

  /// 레벨 모드에서 이 레벨부터 보석 색이 7개. null이면 항상 6색.
  final int? seventhColorFromLevel;

  /// Last Hurrah 자동 발동 점수에 연쇄 콤보 배수를 적용할지.
  final bool lastHurrahComboMultiplier;

  /// 앱 전체의 현재 값. 원격 설정과 URL 적용 결과가 여기에 들어간다.
  static GameplayFlags current = const GameplayFlags();

  static int? _optInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  /// 원격 JSON. 모르는 키와 잘못된 타입은 기본값으로 둔다.
  factory GameplayFlags.fromJson(Map<String, Object?> json) {
    bool flag(String key, bool fallback) {
      final value = json[key];
      return value is bool ? value : fallback;
    }

    final level = _optInt(json['seventh_color_from_level']);
    return GameplayFlags(
      timeRewardT1: flag('time_reward_t1', false),
      timeGem: flag('time_gem', false),
      multiplierGem: flag('multiplier_gem', false),
      seventhColorFromLevel: level != null && level >= 1 ? level : null,
      lastHurrahComboMultiplier: flag('last_hurrah_combo_multiplier', true),
    );
  }

  Map<String, Object?> toJson() => {
    'time_reward_t1': timeRewardT1,
    'time_gem': timeGem,
    'multiplier_gem': multiplierGem,
    'seventh_color_from_level': seventhColorFromLevel,
    'last_hurrah_combo_multiplier': lastHurrahComboMultiplier,
  };

  /// `?exp=` 값을 이 값 위에 덮어쓴다. `none`은 모든 실험을 끈 기본값, `all`은 모두 켠다(7색은 레벨 10부터).
  /// 항목: t1, tg, mg, c7 또는 c7:레벨, lhc, nolhc. 앞에 `-`를 붙이면 끈다(예: `-tg`).
  GameplayFlags withUrlOverride(String? raw) {
    if (raw == null || raw.trim().isEmpty) return this;
    var t1 = timeRewardT1;
    var tg = timeGem;
    var mg = multiplierGem;
    var c7 = seventhColorFromLevel;
    var lhc = lastHurrahComboMultiplier;
    for (final part in raw.split(',')) {
      final token = part.trim().toLowerCase();
      if (token.isEmpty) continue;
      final off = token.startsWith('-');
      final name = off ? token.substring(1) : token;
      switch (name) {
        case 'none':
          t1 = false;
          tg = false;
          mg = false;
          c7 = null;
          lhc = true;
        case 'all':
          t1 = true;
          tg = true;
          mg = true;
          c7 = 10;
        case 't1':
          t1 = !off;
        case 'tg':
          tg = !off;
        case 'mg':
          mg = !off;
        case 'lhc':
          lhc = !off;
        case 'nolhc':
          lhc = false;
        default:
          if (name == 'c7' || name.startsWith('c7:')) {
            if (off) {
              c7 = null;
            } else {
              final level = name.length > 3
                  ? int.tryParse(name.substring(3))
                  : null;
              c7 = level != null && level >= 1 ? level : 10;
            }
          }
      }
    }
    return GameplayFlags(
      timeRewardT1: t1,
      timeGem: tg,
      multiplierGem: mg,
      seventhColorFromLevel: c7,
      lastHurrahComboMultiplier: lhc,
    );
  }

  /// 이벤트에 붙이는 짧은 표시. 실험을 켠 판과 끈 판을 나눠 보려고 쓴다. 모두 기본값이면 빈 문자열.
  String get tag {
    final parts = <String>[
      if (timeRewardT1) 't1',
      if (timeGem) 'tg',
      if (multiplierGem) 'mg',
      if (seventhColorFromLevel != null) 'c7:$seventhColorFromLevel',
      if (!lastHurrahComboMultiplier) 'nolhc',
    ];
    return parts.join(',');
  }

  @override
  bool operator ==(Object other) =>
      other is GameplayFlags &&
      other.timeRewardT1 == timeRewardT1 &&
      other.timeGem == timeGem &&
      other.multiplierGem == multiplierGem &&
      other.seventhColorFromLevel == seventhColorFromLevel &&
      other.lastHurrahComboMultiplier == lastHurrahComboMultiplier;

  @override
  int get hashCode => Object.hash(
    timeRewardT1,
    timeGem,
    multiplierGem,
    seventhColorFromLevel,
    lastHurrahComboMultiplier,
  );
}
