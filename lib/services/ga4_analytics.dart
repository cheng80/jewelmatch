import 'package:flutter/foundation.dart';

import '../app_config.dart';
import 'ga4_analytics_stub.dart'
    if (dart.library.js_interop) 'ga4_analytics_web.dart';
import 'ga4_event_mapper.dart';
import 'telemetry_policy.dart';

/// gtag.js 명령 창구. 웹은 [createGa4Sink]가 실제 구현을 주고, 테스트는 가짜를 넣는다.
abstract class Ga4Sink {
  /// dataLayer와 gtag 함수를 만들고 gtag.js를 붙인다. 로드 성공이면 true. 예외를 던지지 않는다.
  Future<bool> load(String measurementId);

  /// `gtag(command, target, params)`.
  void gtag(String command, String target, [Map<String, Object?>? params]);

  /// `window['ga-disable-<id>']`.
  void setDisabled(String measurementId, bool disabled);

  /// 이전 페이지 주소. 없으면 빈 문자열.
  String get referrer;

  /// GA4가 남긴 `_ga`, `_ga_<id>` 쿠키를 지운다. 동의 철회와 QA 전환 때 부른다. 예외를 던지지 않는다.
  void clearCookies(String measurementId);
}

/// NAS 웹 GA4 전송(PLAN-011 Step 2). 게임 코드는 이 클래스를 직접 부르지 않고 EventLogger를 거친다.
///
/// - 켜질 수 있는 곳: 웹이고 STORE_CHANNEL이 intoss가 아닌 빌드. 네이티브와 앱인토스는 항상 꺼져 있다.
/// - 보낼 곳: telemetry_env가 production이고 QA 스위치가 꺼졌으면 `GA4_MEASUREMENT_ID`,
///   그 밖에는 `GA4_TEST_MEASUREMENT_ID`(debug_mode)이며 없으면 아예 켜지 않는다.
///   운영 ID로 시작한 뒤 QA 스위치가 켜지면 그 자리에서 끄고 세션 끝까지 다시 켜지 않는다.
/// - 동의 전에는 gtag.js를 싣지 않고 아무 요청도 하지 않는다. [setConsent] true에서 처음 한 번 초기화하고
///   page_view를 한 번 보낸다. false면 ga-disable과 analytics_storage denied로 뒤 전송을 막고 대기열을 버린다.
/// - 광고 저장, 광고 사용자 데이터, 광고 개인화는 늘 denied이고 Google 신호와 광고 개인화 신호는 끈다.
///   User ID는 설정하지 않고, 주소는 query와 fragment를 뺀 origin과 경로만 보낸다.
/// - gtag.js 로드는 기다리지 않는다. 로드 전 이벤트는 [maxPending]건까지 들고 있다가 넘치면 새 것을 버린다.
///   로드가 실패하면 대기열을 버리고 이 세션에서 다시 시도하지 않는다.
/// - 이벤트는 [mapGa4Event] 허용 목록을 통과한 것만 보낸다. 원본 params는 보내지 않는다.
class Ga4Analytics {
  Ga4Analytics({
    this.productionId = const String.fromEnvironment('GA4_MEASUREMENT_ID'),
    this.testId = const String.fromEnvironment('GA4_TEST_MEASUREMENT_ID'),
    bool? supported,
    TelemetryPolicy? policy,
    Ga4Sink? sink,
    Uri Function()? location,
  }) : supported =
           supported ??
           (kIsWeb && AppConfig.storeChannel != StoreChannel.intoss),
       policy = policy ?? TelemetryPolicy.fromBuild(),
       _sink = sink,
       _location = location ?? (() => Uri.base);

  static final Ga4Analytics instance = Ga4Analytics();

  static const int maxPending = 20;
  static const String channel = 'web';

  final String productionId;
  final String testId;
  final bool supported;
  final TelemetryPolicy policy;
  final Uri Function() _location;
  Ga4Sink? _sink;

  Ga4Sink get _gtag => _sink ??= createGa4Sink();

  final List<(String, Map<String, Object>)> _pending = [];
  String? _id;
  bool _production = false;
  bool _granted = false;
  bool _loaded = false;
  bool _dead = false;
  bool _qa = false;

  /// 설정 화면에 분석 허용 스위치를 보일지. 켤 수 있는 빌드이고 보낼 곳이 있을 때만 true.
  bool get available => supported && _target() != null;

  /// gtag.js 로드가 끝나 바로 보내는 중인지.
  bool get sending => _granted && _loaded && !_dead;

  @visibleForTesting
  int get pendingCount => _pending.length;

  bool _qaNow() {
    if (!_qa) {
      try {
        _qa = policy.qaProbe?.call() ?? false;
      } catch (_) {}
    }
    return _qa;
  }

  ({String id, bool production})? _target() {
    final production = policy.env == TelemetryEnv.production && !_qaNow();
    final id = production ? productionId : testId;
    return id.isEmpty ? null : (id: id, production: production);
  }

  /// 저장된 동의 값과 설정 스위치가 부른다. 게임 시작을 막지 않도록 로드는 기다리지 않는다.
  /// 예외는 밖으로 나가지 않는다(앱 시작과 설정 화면을 막지 않는다). 실패하면 이 세션에서는 멈춘다.
  void setConsent(bool granted) {
    _granted = granted;
    if (!supported || _dead) return;
    try {
      _apply(granted);
    } catch (_) {
      _fail();
    }
  }

  void _fail() {
    _dead = true;
    _pending.clear();
  }

  void _apply(bool granted) {
    final id = _id;
    if (!granted) {
      _pending.clear();
      if (id != null) _deny(id);
      return;
    }
    if (id != null) {
      if (_stopIfQa()) return;
      _gtag.setDisabled(id, false);
      _gtag.gtag('consent', 'update', const {'analytics_storage': 'granted'});
      return;
    }
    final target = _target();
    if (target == null) return;
    _start(target.id, target.production);
  }

  /// 이후 전송을 막고 동의를 거부로 바꾸며 이미 남은 GA 쿠키를 지운다.
  void _deny(String id) {
    _gtag.setDisabled(id, true);
    _gtag.gtag('consent', 'update', const {'analytics_storage': 'denied'});
    _gtag.clearCookies(id);
  }

  void _start(String id, bool production) {
    _id = id;
    _production = production;
    final sink = _gtag;
    // 동의 기본값은 측정 명령보다 먼저 쌓는다.
    sink.gtag('consent', 'default', const {
      'ad_storage': 'denied',
      'ad_user_data': 'denied',
      'ad_personalization': 'denied',
      'analytics_storage': 'granted',
    });
    sink.gtag('js', '');
    final page = _pageLocation();
    sink.gtag('config', id, {
      'send_page_view': false,
      'cookie_prefix': 'sm',
      'cookie_domain': 'none',
      'cookie_path': '/match/',
      'allow_google_signals': false,
      'allow_ad_personalization_signals': false,
      'page_location': page,
      'page_referrer': _stripUrl(sink.referrer),
      if (!production) 'debug_mode': true,
    });
    _queue('page_view', {'page_location': page});
    sink
        .load(id)
        .then((ok) {
          if (ok && !_dead) {
            _loaded = true;
            final ready = List.of(_pending);
            _pending.clear();
            // 로드 사이에 동의 철회나 QA 진입이 있었을 수 있어 보낼 때마다 다시 확인한다([_send]).
            for (final (name, params) in ready) {
              _send(name, params);
            }
          } else {
            _fail();
          }
        })
        .catchError((_) => _fail());
  }

  /// EventLogger가 모든 내부 이벤트를 넘긴다. 매핑되지 않거나 꺼진 상태면 버린다.
  void track(
    String name,
    Map<String, Object?> params, {
    int? attemptSeq,
    String? appVersion,
    int? schemaVersion,
  }) {
    if (!_granted || _id == null || _dead || _stopIfQa()) return;
    final Ga4Event? event;
    try {
      event = mapGa4Event(
        name,
        params,
        channel: channel,
        appVersion: appVersion,
        schemaVersion: schemaVersion,
        attemptSeq: attemptSeq,
      );
    } catch (_) {
      return;
    }
    if (event == null) return;
    _queue(event.name, event.params);
  }

  void _queue(String name, Map<String, Object> params) {
    if (_loaded) {
      _send(name, params);
    } else if (_pending.length < maxPending) {
      _pending.add((name, params));
    }
  }

  /// 보내기 직전 마지막 관문. 동의 철회, 실패, QA 진입이면 보내지 않는다.
  /// 이벤트마다 query와 fragment를 뺀 page_location을 명시한다(gtag의 기본값은 query가 붙은 현재 주소).
  void _send(String name, Map<String, Object> params) {
    try {
      if (!_granted || _dead || _stopIfQa()) return;
      final page = _pageLocation();
      _gtag.gtag('event', name, {
        ...params,
        if (page.isNotEmpty) 'page_location': page,
        'send_to': _id,
      });
    } catch (_) {}
  }

  /// 운영 ID로 보내던 중 QA가 켜지면 끄고 세션 끝까지 멈춘다. 테스트 ID는 QA에서도 계속 보낸다.
  bool _stopIfQa() {
    if (!_production || !_qaNow()) return false;
    _dead = true;
    _pending.clear();
    final id = _id;
    if (id != null) {
      try {
        _deny(id);
      } catch (_) {}
    }
    return true;
  }

  String _pageLocation() {
    try {
      return _stripUrl(_location().toString());
    } catch (_) {
      return '';
    }
  }
}

/// query, fragment, 사용자 정보를 뺀 origin과 경로. http(s)가 아니거나 해석할 수 없으면 빈 문자열.
@visibleForTesting
String stripGa4Url(String url) => _stripUrl(url);

String _stripUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
    return '';
  }
  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: uri.path,
  ).toString();
}
