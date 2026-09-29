import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/game/round_timing.dart';

void main() {
  late Duration clock;
  late RoundTiming timing;

  void tick(int ms) => clock += Duration(milliseconds: ms);

  Map<String, Object?> snap() => timing.snapshot();

  void expectSnap(
    double active,
    double system,
    double paused,
    double background,
  ) {
    final s = snap();
    expect(s['active_s'], closeTo(active, 1e-9));
    expect(s['system_s'], closeTo(system, 1e-9));
    expect(s['paused_s'], closeTo(paused, 1e-9));
    expect(s['background_s'], closeTo(background, 1e-9));
    expect(
      s['duration_s'],
      closeTo(active + system + paused + background, 1e-9),
    );
  }

  setUp(() {
    clock = const Duration(seconds: 100);
    timing = RoundTiming(now: () => clock);
  });

  test('reset 전 snapshot과 setPhase는 0이고 무시된다', () {
    tick(500);
    timing.setPhase(RoundPhase.active);
    tick(500);
    expectSnap(0, 0, 0, 0);
  });

  test('기본 상태는 system이고 상태 경계마다 정산한다', () {
    timing.reset();
    tick(1000);
    timing.setPhase(RoundPhase.active);
    tick(2500);
    timing.setPhase(RoundPhase.paused);
    tick(300);
    timing.setPhase(RoundPhase.background);
    tick(200);
    timing.setPhase(RoundPhase.active);
    tick(1);
    expectSnap(2.501, 1, 0.3, 0.2);
  });

  test('reset은 시작 상태를 지정하고 누적을 지운다', () {
    timing.reset(phase: RoundPhase.active);
    tick(4000);
    timing.reset(phase: RoundPhase.paused);
    tick(700);
    expectSnap(0, 0, 0.7, 0);
  });

  test('snapshot은 상태를 바꾸지 않고 반복 호출해도 같다', () {
    timing.reset(phase: RoundPhase.active);
    tick(1500);
    final a = snap();
    expect(snap(), a);
    tick(500);
    expectSnap(2, 0, 0, 0);
    timing.setPhase(RoundPhase.paused);
    tick(1000);
    snap();
    tick(1000);
    expectSnap(2, 0, 2, 0);
  });

  test('같은 상태로 반복 전환해도 합계가 유지된다', () {
    timing.reset(phase: RoundPhase.active);
    tick(1000);
    timing.setPhase(RoundPhase.active);
    tick(1000);
    timing.setPhase(RoundPhase.active);
    expectSnap(2, 0, 0, 0);
  });

  test('종료 snapshot은 타이머를 멈추지 않고 다음 시도에 이어서 누적한다', () {
    timing.reset(phase: RoundPhase.active);
    tick(3000);
    timing.setPhase(RoundPhase.paused);
    final end = snap();
    expect(end['duration_s'], 3.0);
    tick(5000); // 결과 화면, 광고
    timing.setPhase(RoundPhase.background);
    tick(1000);
    timing.setPhase(RoundPhase.active);
    tick(2000);
    expectSnap(5, 0, 5, 1);
    expect(snap()['duration_s'], 11.0);
  });

  test('background 우선은 호출자가 상태를 바꿔 표현한다', () {
    timing.reset(phase: RoundPhase.active);
    tick(1000);
    timing.setPhase(RoundPhase.background); // 활성 중 백그라운드
    tick(4000);
    timing.setPhase(RoundPhase.active); // 복귀
    tick(1000);
    expectSnap(2, 0, 0, 4);
  });

  test('시계가 뒤로 가면 마지막 관측값으로 고정해 음수가 없다', () {
    timing.reset(phase: RoundPhase.active);
    tick(2000);
    timing.setPhase(RoundPhase.paused);
    clock -= const Duration(seconds: 50);
    expectSnap(2, 0, 0, 0);
    timing.setPhase(RoundPhase.system);
    expectSnap(2, 0, 0, 0);
    clock = const Duration(seconds: 100, milliseconds: 2500);
    expectSnap(2, 0.5, 0, 0); // 고정된 102s 이후 경과만 현재 상태(system)에 더한다
  });

  test('snapshot 뒤 시계가 뒤로 가도 조회값은 줄지 않고 전환에 이어진다', () {
    timing.reset(); // system, 100s
    tick(10000);
    expectSnap(0, 10, 0, 0);
    clock -= const Duration(seconds: 5); // 105s
    expectSnap(0, 10, 0, 0);
    timing.setPhase(RoundPhase.active);
    expectSnap(0, 10, 0, 0);
    clock = const Duration(seconds: 112);
    expectSnap(2, 10, 0, 0); // snapshot이 본 110s 이후만 active
    timing.reset(); // reset은 기준 시각을 다시 잡는다
    expectSnap(0, 0, 0, 0);
  });

  test('기본 시계는 단조 Stopwatch라 snapshot이 음수가 아니고 줄지 않는다', () {
    final real = RoundTiming()..reset(phase: RoundPhase.active);
    final a = real.snapshot()['duration_s']! as double;
    final b = real.snapshot()['duration_s']! as double;
    expect(a, greaterThanOrEqualTo(0));
    expect(b, greaterThanOrEqualTo(a));
  });
}
