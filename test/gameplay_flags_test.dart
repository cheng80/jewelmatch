import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/game/gameplay_flags.dart';

void main() {
  test('defaults keep current behavior and tag is empty', () {
    const flags = GameplayFlags();
    expect(flags.timeRewardT1, isFalse);
    expect(flags.timeGem, isFalse);
    expect(flags.multiplierGem, isFalse);
    expect(flags.seventhColorFromLevel, isNull);
    expect(flags.lastHurrahComboMultiplier, isTrue);
    expect(flags.tag, '');
  });

  test('fromJson ignores bad types and round trips', () {
    final flags = GameplayFlags.fromJson({
      'time_reward_t1': true,
      'time_gem': 'yes',
      'multiplier_gem': true,
      'seventh_color_from_level': 12,
      'last_hurrah_combo_multiplier': false,
    });
    expect(flags.timeRewardT1, isTrue);
    expect(flags.timeGem, isFalse);
    expect(flags.multiplierGem, isTrue);
    expect(flags.seventhColorFromLevel, 12);
    expect(flags.lastHurrahComboMultiplier, isFalse);
    expect(GameplayFlags.fromJson(flags.toJson()), flags);
    expect(flags.tag, 't1,mg,c7:12,nolhc');
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
    expect(base.withUrlOverride('all').tag, 't1,tg,mg,c7:10');
    expect(base.withUrlOverride('-tg,t1,c7:6,nolhc').tag, 't1,c7:6,nolhc');
    expect(base.withUrlOverride('c7').seventhColorFromLevel, 10);
    expect(base.withUrlOverride('unknown, MG ').tag, 'tg,mg');
    // all, none, nolhc 앞의 '-'는 무시한다(검수 R4 P3-5).
    expect(base.withUrlOverride('-all'), base);
    expect(base.withUrlOverride('-none'), base);
    expect(base.withUrlOverride('-nolhc'), base);
  });
}
