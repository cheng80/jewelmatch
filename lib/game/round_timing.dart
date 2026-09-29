/// 판 시간 누적 상태. 한 시점에는 하나만 누적한다(background 우선은 호출자가 정한다).
enum RoundPhase { active, system, paused, background }

/// 단조 시계 기반 순수 판 시간 누적기. 프레임 dt와 벽시계를 쓰지 않는다.
class RoundTiming {
  RoundTiming({Duration Function()? now}) : _now = now ?? _stopwatchNow();

  static Duration Function() _stopwatchNow() {
    final stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsed;
  }

  final Duration Function() _now;
  final _totalsUs = List<int>.filled(RoundPhase.values.length, 0);
  bool _started = false;
  RoundPhase _phase = RoundPhase.system;
  Duration _last = Duration.zero;

  /// 지금까지 관측한 가장 늦은 시각(snapshot 포함). 조회값이 뒤로 가지 않게 한다.
  Duration _watermark = Duration.zero;

  /// 새 판을 시작하고 누적 시간을 지운다.
  void reset({RoundPhase phase = RoundPhase.system}) {
    _totalsUs.fillRange(0, _totalsUs.length, 0);
    _started = true;
    _phase = phase;
    _last = _watermark = _now();
  }

  /// 이전 상태를 지금까지 정산하고 새 상태로 바꾼다. 같은 상태 반복은 무해하다.
  void setPhase(RoundPhase phase) {
    if (!_started) return;
    _settle();
    _phase = phase;
  }

  /// 상태를 바꾸지 않는 조회. 진행 중 상태의 경과 시간을 포함한다.
  Map<String, Object?> snapshot() {
    final us = List<int>.of(_totalsUs);
    if (_started) {
      us[_phase.index] += _observe().inMicroseconds - _last.inMicroseconds;
    }
    double s(RoundPhase p) => us[p.index] / Duration.microsecondsPerSecond;
    return {
      'duration_s':
          us.fold<int>(0, (a, b) => a + b) / Duration.microsecondsPerSecond,
      'active_s': s(RoundPhase.active),
      'system_s': s(RoundPhase.system),
      'paused_s': s(RoundPhase.paused),
      'background_s': s(RoundPhase.background),
    };
  }

  void _settle() {
    final t = _observe();
    _totalsUs[_phase.index] += t.inMicroseconds - _last.inMicroseconds;
    _last = t;
  }

  /// 주입 시계가 뒤로 가면 마지막 관측값(snapshot 포함)으로 고정한다.
  Duration _observe() {
    final t = _now();
    if (t > _watermark) _watermark = t;
    return _watermark;
  }
}
