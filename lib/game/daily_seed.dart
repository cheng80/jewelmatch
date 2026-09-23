import 'dart:convert';
import 'dart:math';

/// 타임 모드 일일 동일 보드의 날짜 키와 시드. 날짜는 KST(UTC+9 고정)로 센다.
abstract final class DailySeed {
  static const String _prefix = 'stone-match-daily-v1:';

  /// [now] 시각의 KST 날짜 키(YYYY-MM-DD).
  static String keyFor(DateTime now) {
    final kst = now.toUtc().add(const Duration(hours: 9));
    String two(int v) => v.toString().padLeft(2, '0');
    return '${kst.year.toString().padLeft(4, '0')}-${two(kst.month)}-${two(kst.day)}';
  }

  /// "stone-match-daily-v1:YYYY-MM-DD"의 FNV-1a 32비트 해시.
  static int seedFor(String key) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode('$_prefix$key')) {
      hash ^= byte;
      // hash * 0x01000193을 웹에서도 2^53 안에서 계산한다.
      hash = (hash * 0x193 + ((hash & 0xff) << 24)) & 0xffffffff;
    }
    return hash;
  }
}

/// 시드 고정 난수(xorshift32). `Random(seed)`는 Dart 릴리스마다 수열이 바뀔 수
/// 있어 같은 날 모든 플랫폼이 같은 보드를 받도록 직접 구현한다.
class DailyRandom implements Random {
  DailyRandom(int seed)
    : _state = (seed & 0xffffffff) == 0 ? 1 : seed & 0xffffffff;

  int _state;

  int _next() {
    var x = _state;
    x ^= (x << 13) & 0xffffffff;
    x ^= x >> 17;
    x ^= (x << 5) & 0xffffffff;
    return _state = x;
  }

  @override
  int nextInt(int max) {
    if (max <= 0 || max > 0x100000000) {
      throw RangeError.range(max, 1, 0x100000000, 'max');
    }
    return _next() % max;
  }

  @override
  double nextDouble() => _next() / 0x100000000;

  @override
  bool nextBool() => _next() & 0x80000000 != 0;
}
