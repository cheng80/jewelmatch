import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stonematch/services/backend/pocketbase_config.dart';
import 'package:stonematch/services/backend/pocketbase_gateway.dart';
import 'package:stonematch/services/event_logger.dart';
import 'package:stonematch/services/ga4_analytics.dart';
import 'package:stonematch/services/game_settings.dart';
import 'package:stonematch/services/play_event_context.dart';
import 'package:stonematch/services/telemetry_policy.dart';
import 'package:stonematch/utils/storage_helper.dart';
import 'package:stonematch/vm/settings_notifier.dart';

class _FakeSink implements Ga4Sink {
  final calls = <List<Object?>>[];
  final disabled = <String, bool>{};
  int loads = 0;
  Completer<bool> loader = Completer<bool>();

  @override
  Future<bool> load(String measurementId) {
    loads++;
    calls.add(['load', measurementId]);
    return loader.future;
  }

  @override
  void gtag(String command, String target, [Map<String, Object?>? params]) =>
      calls.add([command, target, params]);

  @override
  void setDisabled(String measurementId, bool disabled) =>
      this.disabled[measurementId] = disabled;

  @override
  String get referrer => 'https://ref.example/a?q=secret#x';

  final cleared = <String>[];

  @override
  void clearCookies(String measurementId) => cleared.add(measurementId);

  List<List<Object?>> get events =>
      calls.where((c) => c[0] == 'event').toList();
}

class _ThrowingSink extends _FakeSink {
  _ThrowingSink({this.throwOnLoad = false});
  final bool throwOnLoad;
  int eventCalls = 0;

  @override
  Future<bool> load(String measurementId) {
    if (throwOnLoad) throw StateError('load');
    return super.load(measurementId);
  }

  @override
  void gtag(String command, String target, [Map<String, Object?>? params]) {
    if (command == 'event') eventCalls++;
    if (!throwOnLoad) throw StateError('gtag');
    super.gtag(command, target, params);
  }
}

const _prod = TelemetryPolicy(env: TelemetryEnv.production);
final _pageUri = Uri.parse(
  'https://user:pw@nas.example:8443/match/game?name=kim&qaX=0#frag',
);

Ga4Analytics _ga4(
  _FakeSink sink, {
  TelemetryPolicy policy = _prod,
  bool supported = true,
  String productionId = 'G-PROD',
  String testId = '',
}) => Ga4Analytics(
  productionId: productionId,
  testId: testId,
  supported: supported,
  policy: policy,
  sink: sink,
  location: () => _pageUri,
);

const _roundStart = {'mode': 'timed', 'player_name': 'kim'};

void main() {
  test('웹이 아니거나 앱인토스면 동의해도 아무 호출도 하지 않는다', () {
    final sink = _FakeSink();
    final ga4 = _ga4(sink, supported: false);
    ga4.setConsent(true);
    ga4.track('round_start', _roundStart);
    expect(ga4.available, isFalse);
    expect(sink.calls, isEmpty);
    expect(sink.loads, 0);
  });

  test('동의 전에는 gtag.js를 싣지 않고 이벤트도 버린다', () {
    final sink = _FakeSink();
    final ga4 = _ga4(sink);
    expect(ga4.available, isTrue);
    ga4.setConsent(false);
    ga4.track('round_start', _roundStart);
    expect(sink.calls, isEmpty);
    expect(ga4.pendingCount, 0);
  });

  test('동의하면 동의 기본값, config, page_view 한 번 뒤 로드 완료 시 순서대로 보낸다', () async {
    final sink = _FakeSink();
    final ga4 = _ga4(sink);
    ga4.setConsent(true);

    expect(sink.calls[0], [
      'consent',
      'default',
      {
        'ad_storage': 'denied',
        'ad_user_data': 'denied',
        'ad_personalization': 'denied',
        'analytics_storage': 'granted',
      },
    ]);
    expect(sink.calls[1][0], 'js');
    expect(sink.calls[2], [
      'config',
      'G-PROD',
      {
        'send_page_view': false,
        'cookie_prefix': 'sm',
        'cookie_domain': 'none',
        'cookie_path': '/match/',
        'allow_google_signals': false,
        'allow_ad_personalization_signals': false,
        'page_location': 'https://nas.example:8443/match/game',
        'page_referrer': 'https://ref.example/a',
      },
    ]);
    expect(sink.calls[3], ['load', 'G-PROD']);

    // 로드 전에는 보내지 않고 들고 있는다.
    ga4.track('round_start', _roundStart);
    ga4.track('hyper_swap', const {}); // 매핑 제외
    expect(sink.events, isEmpty);
    expect(ga4.pendingCount, 2);

    sink.loader.complete(true);
    await pumpEventQueue();
    expect(ga4.sending, isTrue);
    expect(sink.events.map((e) => e[1]), ['page_view', 'level_start']);
    expect(sink.events[0][2], {
      'page_location': 'https://nas.example:8443/match/game',
      'send_to': 'G-PROD',
    });
    final start = sink.events[1][2]! as Map<String, Object?>;
    expect(start['app_channel'], 'web');
    expect(start['send_to'], 'G-PROD');
    expect(start.containsKey('player_name'), isFalse);
    expect(start.containsKey('user_id'), isFalse);

    ga4.track('title_menu_action', const {'action': 'settings'});
    expect(sink.events.last[1], 'title_menu_action');

    // 다시 켜도 page_view나 로드를 반복하지 않는다.
    ga4.setConsent(true);
    expect(sink.loads, 1);
    expect(sink.events.where((e) => e[1] == 'page_view'), hasLength(1));
  });

  test('로드 전 대기열은 20건에서 멈추고 로드 실패면 버리고 다시 시도하지 않는다', () async {
    final sink = _FakeSink();
    final ga4 = _ga4(sink);
    ga4.setConsent(true);
    for (var i = 0; i < 30; i++) {
      ga4.track('round_start', _roundStart);
    }
    expect(ga4.pendingCount, Ga4Analytics.maxPending);

    sink.loader.complete(false);
    await pumpEventQueue();
    expect(ga4.pendingCount, 0);
    ga4.track('round_start', _roundStart);
    ga4.setConsent(false);
    ga4.setConsent(true);
    expect(sink.loads, 1);
    expect(sink.events, isEmpty);
  });

  test('끄면 ga-disable, analytics_storage denied, 대기열 폐기 뒤 더 보내지 않는다', () async {
    final sink = _FakeSink();
    final ga4 = _ga4(sink);
    ga4.setConsent(true);
    ga4.track('round_start', _roundStart);
    ga4.setConsent(false);
    expect(ga4.pendingCount, 0);
    expect(sink.disabled['G-PROD'], isTrue);
    expect(sink.calls.last, [
      'consent',
      'update',
      {'analytics_storage': 'denied'},
    ]);

    sink.loader.complete(true);
    await pumpEventQueue();
    ga4.track('round_start', _roundStart);
    expect(sink.events, isEmpty);

    ga4.setConsent(true);
    expect(sink.disabled['G-PROD'], isFalse);
    ga4.track('round_start', _roundStart);
    expect(sink.events.map((e) => e[1]), ['level_start']);
  });

  test('운영 ID로 보내다 QA가 켜지면 바로 멈추고 다시 켜지지 않는다', () async {
    var qa = false;
    final sink = _FakeSink();
    final ga4 = _ga4(
      sink,
      policy: TelemetryPolicy(env: TelemetryEnv.production, qaProbe: () => qa),
      testId: 'G-TEST',
    );
    ga4.setConsent(true);
    sink.loader.complete(true);
    await pumpEventQueue();
    ga4.track('round_start', _roundStart);
    expect(sink.events, hasLength(2));

    qa = true;
    ga4.track('round_start', _roundStart);
    expect(sink.events, hasLength(2));
    expect(sink.disabled['G-PROD'], isTrue);
    ga4.setConsent(true);
    ga4.track('round_start', _roundStart);
    expect(sink.events, hasLength(2));
    expect(sink.calls.where((c) => c[1] == 'G-TEST'), isEmpty);
  });

  test('QA와 개발 환경은 테스트 ID를 debug_mode로만 쓰고 없으면 완전히 꺼진다', () {
    final none = _FakeSink();
    final off = _ga4(none, policy: const TelemetryPolicy(env: TelemetryEnv.qa));
    expect(off.available, isFalse);
    off.setConsent(true);
    expect(none.calls, isEmpty);

    final sink = _FakeSink();
    final ga4 = _ga4(
      sink,
      policy: TelemetryPolicy(
        env: TelemetryEnv.production,
        qaProbe: () => true,
      ),
      testId: 'G-TEST',
    );
    ga4.setConsent(true);
    final config = sink.calls.firstWhere((c) => c[0] == 'config');
    expect(config[1], 'G-TEST');
    expect((config[2]! as Map)['debug_mode'], isTrue);
  });

  test('운영 환경은 운영 ID가 없으면 테스트 ID로 떨어지지 않는다', () {
    final ga4 = _ga4(_FakeSink(), productionId: '', testId: 'G-TEST');
    expect(ga4.available, isFalse);
  });

  test('주소는 query, fragment, 사용자 정보를 뺀다', () {
    expect(
      stripGa4Url('https://a:b@x.example/p/q?name=kim#t=1'),
      'https://x.example/p/q',
    );
    expect(stripGa4Url('javascript:alert(1)'), '');
    expect(stripGa4Url(''), '');
  });

  test('EventLogger는 백엔드 설정과 표본과 무관하게 GA4로 넘긴다', () async {
    final sink = _FakeSink();
    final ga4 = _ga4(sink);
    ga4.setConsent(true);
    sink.loader.complete(true);
    await pumpEventQueue();

    final logger = EventLogger(
      gateway: PocketBaseGateway(config: const PocketBaseConfig(url: '')),
      policy: const TelemetryPolicy(
        env: TelemetryEnv.test,
        sessionSampled: false,
      ),
      ga4: ga4,
    );
    addTearDown(logger.dispose);
    logger.appVersion = '1.2.3+4';
    final ctx = PlayEventContext.startRun().nextAttempt();
    logger.logPlay('round_end', ctx, const {
      'mode': 'timed',
      'reason': 'time_up',
      'score': 10,
    });
    logger.logBehavior('title_menu_action', const {'action': 'ranking'});
    logger.log('badge_earned', const {'badge': 'bombMaker', 'tier': 1});

    expect(logger.pendingCount, 0);
    expect(sink.events.skip(1).map((e) => e[1]), [
      'level_end',
      'title_menu_action',
      'unlock_achievement',
    ]);
    final end = sink.events[1][2]! as Map<String, Object?>;
    expect(end['attempt_seq'], ctx.attemptSeq);
    expect(end['app_ver'], '1.2.3+4');
    expect(end['schema_ver'], EventLogger.schemaVersion);
  });

  test('철회하면 남은 GA 쿠키도 지운다(QA 전환도 같다)', () async {
    final sink = _FakeSink();
    final ga4 = _ga4(sink);
    ga4.setConsent(true);
    ga4.setConsent(false);
    expect(sink.cleared, ['G-PROD']);

    var qa = false;
    final qaSink = _FakeSink();
    final qaGa4 = _ga4(
      qaSink,
      policy: TelemetryPolicy(env: TelemetryEnv.production, qaProbe: () => qa),
    );
    qaGa4.setConsent(true);
    qaSink.loader.complete(true);
    await pumpEventQueue();
    qa = true;
    qaGa4.track('round_start', _roundStart);
    expect(qaSink.cleared, ['G-PROD']);
  });

  test('로드 중 QA가 켜지면 대기열도 운영 ID로 나가지 않는다', () async {
    var qa = false;
    final sink = _FakeSink();
    final ga4 = _ga4(
      sink,
      policy: TelemetryPolicy(env: TelemetryEnv.production, qaProbe: () => qa),
      testId: 'G-TEST',
    );
    ga4.setConsent(true);
    ga4.track('round_start', _roundStart);
    expect(ga4.pendingCount, 2);
    qa = true;
    sink.loader.complete(true);
    await pumpEventQueue();
    expect(sink.events, isEmpty);
    expect(sink.disabled['G-PROD'], isTrue);
    expect(ga4.sending, isFalse);
  });

  test('모든 이벤트에 query와 fragment를 뺀 page_location을 명시한다', () async {
    final sink = _FakeSink();
    final ga4 = _ga4(sink);
    ga4.setConsent(true);
    sink.loader.complete(true);
    await pumpEventQueue();
    ga4.track('round_start', _roundStart);
    for (final call in sink.events) {
      final params = call[2]! as Map<String, Object?>;
      expect(params['page_location'], 'https://nas.example:8443/match/game');
      expect('$params', isNot(contains('qaX')));
      expect('$params', isNot(contains('name=kim')));
      expect('$params', isNot(contains('frag')));
    }
    expect(sink.events, isNotEmpty);
  });

  test('gtag 명령이 예외를 던져도 setConsent는 던지지 않고 이 세션에서 멈춘다', () async {
    final sink = _ThrowingSink();
    final ga4 = _ga4(sink);
    expect(() => ga4.setConsent(true), returnsNormally);
    ga4.track('round_start', _roundStart);
    expect(sink.eventCalls, 0);
    expect(ga4.pendingCount, 0);
    expect(() => ga4.setConsent(false), returnsNormally);
    expect(() => ga4.setConsent(true), returnsNormally);
    expect(sink.loads, 0, reason: '멈춘 뒤에는 다시 시도하지 않는다');

    // load가 동기 예외를 던지는 경우도 같다.
    final loadSink = _ThrowingSink(throwOnLoad: true);
    final loadGa4 = _ga4(loadSink);
    expect(() => loadGa4.setConsent(true), returnsNormally);
    loadGa4.track('round_start', _roundStart);
    expect(loadSink.eventCalls, 0);
  });

  group('설정', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await StorageHelper.init();
      await StorageHelper.erase();
    });

    test('분석 허용은 기본 꺼짐이고 켜면 저장된다', () {
      expect(GameSettings.analyticsConsent, isFalse);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(settingsProvider).analyticsConsent, isFalse);

      container.read(settingsProvider.notifier).setAnalyticsConsent(true);

      expect(container.read(settingsProvider).analyticsConsent, isTrue);
      expect(GameSettings.analyticsConsent, isTrue);
    });
  });
}
