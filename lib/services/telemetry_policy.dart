import 'package:flutter/foundation.dart';

/// 이벤트가 어느 빌드/환경에서 나왔는지 구분하는 값(PLAN-009 Step 3). 집계 필터용이며 원격 DB를 나누지 않는다.
enum TelemetryEnv { production, qa, development, test }

/// full은 모든 이벤트를 남기고, sampled는 표본 세션의 행동 이벤트만 남긴다.
enum TelemetryCollection { full, sampled }

/// 수집 환경과 표본 정책. 세션당 값이 바뀌지 않는 순수 값이다.
///
/// - 환경: `--dart-define=TELEMETRY_ENV=production|qa|development`. 비어 있으면 release는 production,
///   debug/profile은 development. 알 수 없는 값(test 포함)은 production이 되지 않고 development로 떨어진다.
/// - 실제 QA 스위치(query 또는 hash 라우트 query의 qa*=1, QA_PERF_AUTORUN, QA_SPECIAL_EFFECTS,
///   QA_SPECIAL_EFFECTS_CHAIN, QA_PERF_LABEL)가 하나라도 켜지면 정의와 무관하게 qa다.
///   라우트로 늦게 켜질 수 있어 EventLogger가 이벤트를 쌓을 때마다 [qaProbe]를 보고, 한 번 켜지면 세션 끝까지 유지한다.
///   `test`는 생성자로만 주입한다.
/// - 표본: 세션 ID의 FNV-1a 32비트 해시 버킷으로 세션 단위 고정. 이벤트마다 난수를 쓰지 않는다.
///   JS와 VM에서 같은 값이 나오도록 2^53 안의 정수 연산만 쓴다.
class TelemetryPolicy {
  const TelemetryPolicy({
    this.env = TelemetryEnv.development,
    this.sampleRate = defaultSampleRate,
    this.maxSampledEvents = defaultMaxSampledEvents,
    this.sessionSampled,
    this.qaProbe,
  });

  /// 빌드 정의와 실행 환경에서 정책을 만든다. 인자는 테스트 주입용이다.
  factory TelemetryPolicy.fromBuild({
    String? envDefine,
    bool? release,
    bool? qaActive,
    bool Function()? qaProbe,
    double sampleRate = defaultSampleRate,
    int maxSampledEvents = defaultMaxSampledEvents,
    bool? sessionSampled,
  }) => TelemetryPolicy(
    env: resolveEnv(
      define: envDefine ?? _envDefine,
      release: release ?? kReleaseMode,
      qaActive: qaActive ?? false,
    ),
    sampleRate: sampleRate,
    maxSampledEvents: maxSampledEvents,
    sessionSampled: sessionSampled,
    // qaActive를 명시하면 그 값으로 고정한다. 아니면 이벤트마다 실제 URL과 정의를 본다.
    qaProbe: qaProbe ?? (qaActive == null ? isQaActive : null),
  );

  static const double defaultSampleRate = 0.1;
  static const int defaultMaxSampledEvents = 40;

  static const String _envDefine = String.fromEnvironment('TELEMETRY_ENV');
  static const bool _qaDefineActive =
      bool.fromEnvironment('QA_PERF_AUTORUN') ||
      bool.fromEnvironment('QA_SPECIAL_EFFECTS') ||
      bool.fromEnvironment('QA_SPECIAL_EFFECTS_CHAIN') ||
      String.fromEnvironment('QA_PERF_LABEL') != '';

  /// QA 스위치를 제외한 기본 환경. 실제 환경은 EventLogger가 [qaProbe]와 합쳐 정한다.
  final TelemetryEnv env;

  /// 지금 QA 스위치가 켜졌는지 보는 함수. null이면 QA를 감지하지 않는다(테스트 격리).
  final bool Function()? qaProbe;

  /// 표본 세션 비율. 0..1로 잘리고 NaN은 0으로 본다.
  final double sampleRate;

  /// 표본 세션이 세션당 받는 행동 이벤트 상한.
  final int maxSampledEvents;

  /// 지정하면 해시 대신 이 값으로 표본 여부를 정한다(테스트 주입).
  final bool? sessionSampled;

  double get _rate => sampleRate.isNaN ? 0 : sampleRate.clamp(0.0, 1.0);

  /// full 이벤트는 1.0, sampled 이벤트는 표본 비율.
  double rateFor(TelemetryCollection collection) =>
      collection == TelemetryCollection.full ? 1.0 : _rate;

  bool isSessionSampled(String sessionId) =>
      sessionSampled ?? (fnv1a32(sessionId) % 10000) < (_rate * 10000).round();

  static TelemetryEnv resolveEnv({
    required String define,
    required bool release,
    required bool qaActive,
  }) {
    if (qaActive) return TelemetryEnv.qa;
    return switch (define.trim().toLowerCase()) {
      '' => release ? TelemetryEnv.production : TelemetryEnv.development,
      'production' => TelemetryEnv.production,
      'qa' => TelemetryEnv.qa,
      _ => TelemetryEnv.development,
    };
  }

  /// 실제 QA 진입 스위치가 켜졌는지. path 방식 query와 기본 hash 라우팅(`/#/game?qaNoMoves=1`)의
  /// fragment query를 모두 본다. `query`(주면 URL 대신 사용), `uri`, `defines`는 테스트 주입용이다.
  static bool isQaActive({
    Map<String, String>? query,
    Uri? uri,
    bool? defines,
  }) {
    if (defines ?? _qaDefineActive) return true;
    try {
      final queries = query != null ? [query] : _queriesOf(uri ?? Uri.base);
      return queries.any(
        (q) => q.entries.any((e) => e.key.startsWith('qa') && e.value == '1'),
      );
    } catch (_) {
      return false;
    }
  }

  static List<Map<String, String>> _queriesOf(Uri uri) {
    final result = [uri.queryParameters];
    final at = uri.fragment.indexOf('?');
    if (at >= 0) {
      try {
        result.add(Uri.splitQueryString(uri.fragment.substring(at + 1)));
      } catch (_) {} // 잘못된 fragment는 QA로 보지 않는다.
    }
    return result;
  }

  /// FNV-1a 32비트(UTF-16 코드 유닛 기준). `String.hashCode`는 플랫폼마다 달라 쓰지 않는다.
  /// 곱셈은 0x01000193 = 0x193 + 2^24로 나눠 JS 정수 정밀도(2^53) 안에서 계산한다.
  static int fnv1a32(String value) {
    var hash = 0x811c9dc5;
    int step(int h, int byte) =>
        ((h ^ byte) * 0x193 + ((h ^ byte) & 0xFF) * 0x1000000) & 0xFFFFFFFF;
    for (final unit in value.codeUnits) {
      hash = step(hash, unit & 0xFF);
      if (unit > 0xFF) hash = step(hash, unit >> 8);
    }
    return hash;
  }
}
