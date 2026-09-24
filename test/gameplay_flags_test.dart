import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/game/gameplay_flags.dart';

void main() {
  test('defaults are all off and tag is empty', () {
    const flags = GameplayFlags();
    expect(flags.timeRewardT1, isFalse);
    expect(flags.timeGem, isFalse);
    expect(flags.multiplierGem, isFalse);
    expect(flags.seventhColorFromLevel, isNull);
    expect(flags.lastHurrahComboMultiplier, isFalse);
    expect(flags.tag, '');
  });

  test('fromJson ignores bad types and round trips', () {
    final flags = GameplayFlags.fromJson({
      'time_reward_t1': true,
      'time_gem': 'yes',
      'multiplier_gem': true,
      'seventh_color_from_level': 12,
      'last_hurrah_combo_multiplier': true,
    });
    expect(flags.timeRewardT1, isTrue);
    expect(flags.timeGem, isFalse);
    expect(flags.multiplierGem, isTrue);
    expect(flags.seventhColorFromLevel, 12);
    expect(flags.lastHurrahComboMultiplier, isTrue);
    expect(GameplayFlags.fromJson(flags.toJson()), flags);
    expect(flags.tag, 't1,mg,c7:12,lhc');
    // 기존 원격 행의 명시값은 그대로 따르고, 키가 없으면 권장안 기본값(꺼짐)이다.
    expect(
      GameplayFlags.fromJson({
        'last_hurrah_combo_multiplier': false,
      }).lastHurrahComboMultiplier,
      isFalse,
    );
    expect(GameplayFlags.fromJson({}).lastHurrahComboMultiplier, isFalse);
    expect(
      GameplayFlags.fromJson({
        'seventh_color_from_level': 0,
      }).seventhColorFromLevel,
      isNull,
    );
  });

  test('url override', () {
    const base = GameplayFlags(timeGem: true);
    expect(base.withUrlOverride(null), base);
    expect(base.withUrlOverride('none'), const GameplayFlags());
    expect(base.withUrlOverride('all').tag, 't1,tg,mg,c7:10,lhc');
    expect(base.withUrlOverride('-tg,t1,c7:6,lhc').tag, 't1,c7:6,lhc');
    expect(base.withUrlOverride('lhc,nolhc'), base);
    expect(base.withUrlOverride('lhc').withUrlOverride('-lhc'), base);
    expect(base.withUrlOverride('c7').seventhColorFromLevel, 10);
    expect(base.withUrlOverride('unknown, MG ').tag, 'tg,mg');
    // all, none, nolhc 앞의 '-'는 무시한다(검수 R4 P3-5).
    expect(base.withUrlOverride('-all'), base);
    expect(base.withUrlOverride('-none'), base);
    expect(base.withUrlOverride('-nolhc'), base);
  });
}
