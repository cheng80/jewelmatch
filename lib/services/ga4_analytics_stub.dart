import 'ga4_analytics.dart';

/// 웹이 아닌 빌드는 GA4를 켜지 않는다. [Ga4Analytics.supported]가 false라 부르지 않지만 안전하게 아무것도 하지 않는다.
Ga4Sink createGa4Sink() => const _NoopSink();

class _NoopSink implements Ga4Sink {
  const _NoopSink();

  @override
  Future<bool> load(String measurementId) async => false;

  @override
  void gtag(String command, String target, [Map<String, Object?>? params]) {}

  @override
  void setDisabled(String measurementId, bool disabled) {}

  @override
  String get referrer => '';

  @override
  void clearCookies(String measurementId) {}
}
