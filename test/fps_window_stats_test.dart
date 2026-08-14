import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/app.dart';

void main() {
  test('최근 구간의 평균, 최저 FPS와 최대 프레임 공백을 계산한다', () {
    final stats = FpsWindowStats(windowMicros: 1000000)
      ..add(atMicros: 0, frames: 30, elapsedMicros: 500000, maxGapMs: 17)
      ..add(atMicros: 500000, frames: 10, elapsedMicros: 500000, maxGapMs: 90);

    expect(stats.averageFps, 40);
    expect(stats.lowFps, 20);
    expect(stats.maxGapMs, 90);

    stats.add(
      atMicros: 1500001,
      frames: 25,
      elapsedMicros: 500000,
      maxGapMs: 30,
    );

    expect(stats.averageFps, 50);
    expect(stats.lowFps, 50);
    expect(stats.maxGapMs, 30);
  });
}
