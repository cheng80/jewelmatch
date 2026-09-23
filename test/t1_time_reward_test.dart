// 검수 R4 P2-1: T1은 3개짜리 매치 하나만 있는 단계만 0초로 만든다.
import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/game/match_board_logic.dart';

List<int> _bonuses({required bool t1, required bool twoGroups}) {
  final bonuses = <int>[];
  final b = MatchBoardLogic(
    rows: 8,
    cols: 8,
    colorCount: 1000,
    timedModeTimeRewardScale: 0.6,
    onTimedModeTimeBonus: bonuses.add,
  )..setGeometry(x: 0, y: 0, tile: 56);
  b
    ..flags = GameplayFlags(timeRewardT1: t1)
    ..timedModeRules = true
    ..startDailyBoard('2026-09-24');
  for (var r = 0; r < 8; r++) {
    for (var c = 0; c < 8; c++) {
      b.setGem(r, c, b.createGem(r, c, 10 + r * 8 + c, GemKind.normal));
    }
  }
  for (var c = 0; c < 3; c++) {
    b.getGem(0, c)!.color = 1;
    if (twoGroups) b.getGem(4, c + 4)!.color = 2;
  }
  b
    ..combo = 0
    ..state = 'checking';
  b.advanceResolutionStep();
  b.advanceResolutionStep();
  return bonuses;
}

void main() {
  test('T1 gives 0 seconds only for a single plain 3-match', () {
    expect(_bonuses(t1: false, twoGroups: false), [1]);
    expect(_bonuses(t1: true, twoGroups: false), isEmpty);
  });

  test('T1 keeps the reward when two separate 3-matches clear together', () {
    expect(_bonuses(t1: false, twoGroups: true), [1]);
    expect(_bonuses(t1: true, twoGroups: true), [1]);
  });
}
