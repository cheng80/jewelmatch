import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/game/match_board_camera_shake.dart';
import 'package:stonematch/game/match_board_logic.dart';

void main() {
  test('board shake produces earthquake offset then returns to rest', () {
    final shake = MatchBoardCameraShake();

    shake.queue(const SpecialEffectShake(intensity: 6, duration: 0.4));

    final first = shake.update(0.016);
    expect(shake.isActive, isTrue);
    expect(first.length, greaterThan(0));

    final later = shake.update(0.08);
    expect(later.length, greaterThan(0));
    var horizontalTotal = first.x.abs() + later.x.abs();
    var verticalTotal = first.y.abs() + later.y.abs();
    for (var i = 0; i < 8; i++) {
      final sample = shake.update(0.016);
      horizontalTotal += sample.x.abs();
      verticalTotal += sample.y.abs();
    }
    expect(horizontalTotal, greaterThan(verticalTotal));

    final finished = shake.update(0.5);
    expect(finished.length, 0);
    expect(shake.isActive, isFalse);
  });

  test('stronger special shake dominates queued weaker shake', () {
    final shake = MatchBoardCameraShake();

    shake
      ..queue(const SpecialEffectShake(intensity: 2, duration: 0.2))
      ..queue(const SpecialEffectShake(intensity: 7, duration: 0.5));

    final offset = shake.update(0.016);

    expect(shake.isActive, isTrue);
    expect(offset.length, greaterThan(2));
  });
}
