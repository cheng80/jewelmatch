import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../app_config.dart';
import 'backend/backend_gateway.dart';
import 'backend/backend_selector.dart';
import 'backend/pocketbase_config.dart';
import 'error_reporter.dart';
import 'ga4_analytics.dart';
import 'play_event_context.dart';
import 'telemetry_policy.dart';
import 'telemetry_queue.dart';

/// 내부 이벤트 로거(아이템 플랜 3.5차의 AnalyticsService 역할).
///
/// - 게임 코드는 SDK가 아니라 이 클래스만 부른다.
/// - 백엔드가 설정되지 않은 빌드와 테스트에서는 아무것도 하지 않는다.
/// - 개인 식별 정보를 넣지 않는다. 값은 유한한 숫자, bool, 64자 이하 문자열만 12개까지 남긴다.
/// - params에는 호출자가 덮어쓸 수 없는 예약 필드(event_id, event_seq, schema_version)를
///   enqueue 때 한 번 붙인다. logPlay는 PlayEventContext의 run_id, round_seq, attempt_seq도
///   같은 방식으로 붙인다. 전역 현재 문맥은 없고 호출자가 문맥을 넘긴다. 재전송은 같은 행을 다시 보내므로 값이 유지된다.
/// - telemetry_env, collection, sample_rate도 예약 필드다. log/logPlay는 항상 collection=full, sample_rate=1.0이다.
///   logBehavior는 세션 단위 고정 표본(기본 10%)만 최대 maxSampledEvents건까지 남기고 collection=sampled를 붙인다.
/// - 큐는 [TelemetryQueue]로 백엔드 범위별, 이벤트별 키에 저장하고 다음 실행에서 복원한다(PLAN-009 Step 4).
///   행은 성공 응답 뒤에만 지운다. 400/404는 그 배치를 버린다. 429는 60초 이상,
///   네트워크/5xx/401은 제한된 지수 backoff 뒤 같은 행을 그대로 다시 보낸다.
///   각 행은 enqueue 당시 사용자 ID를 소유자로 기억한다. 인증 전 행은 만든 세션의 첫 인증 사용자로
///   확정한다. 소유자와 같은 사용자일 때만 expectedUserId로 보내며 다른 계정으로는 보내지 않는다.
/// - log/logPlay/logBehavior는 백엔드 설정, 표본과 무관하게 모든 이벤트를 [Ga4Analytics.track]에도 넘긴다.
///   GA4로 무엇을 보낼지는 어댑터의 허용 목록과 동의가 정한다(PLAN-011).
/// - 실패는 게임 흐름에 영향을 주지 않는다.
class EventLogger with WidgetsBindingObserver {
  EventLogger({
    required BackendGateway gateway,
    this.flushDelay = const Duration(seconds: 5),
    this.batchSize = 20,
    this.maxQueue = 200,
    this.maxQueueBytes = 256 * 1024,
    this.maxQueueAge = const Duration(days: 7),
    DateTime Function()? now,
    String? sessionId,
    String? channel,
    TelemetryPolicy? policy,
    TelemetryQueueStore? store,
    String storageScope = 'default',
    Ga4Analytics? ga4,
  }) : _gateway = gateway,
       _ga4 = ga4 ?? Ga4Analytics.instance,
       _now = now ?? DateTime.now,
       sessionId = sessionId ?? uuidV4(),
       channel = channel ?? AppConfig.storeChannel.name,
       policy = policy ?? TelemetryPolicy.fromBuild() {
    _queue = TelemetryQueue(
      store: store ?? MemoryTelemetryQueueStore(),
      scope: storageScope,
      maxRows: maxQueue,
      maxBytes: maxQueueBytes,
      maxAge: maxQueueAge,
      nowMs: () => _now().millisecondsSinceEpoch,
    );
  }

  static final EventLogger instance = EventLogger(
    gateway: BackendSelector.instance,
    store: const PrefsTelemetryQueueStore(),
    // 사용자 ID는 백엔드마다 다르므로 서버 주소별로 큐를 나눈다.
    storageScope: PocketBaseConfig.fromEnvironment.isConfigured
        ? PocketBaseConfig.fromEnvironment.baseUrl
        : 'default',
  );

  /// 연속 실패 backoff. 네트워크/5xx/401은 5초부터 두 배씩 최대 5분, 429는 최소 60초.
  static const Duration minBackoff = Duration(seconds: 5);
  static const Duration maxBackoff = Duration(minutes: 5);
  static const Duration rateLimitBackoff = Duration(seconds: 60);

  static final RegExp _namePattern = RegExp(r'^[a-z][a-z0-9_]{0,39}$');
  static const int _maxParams = 12;
  static const int _maxStringLength = 64;

  /// DB 제약은 jsonb 2048바이트다. jsonb 헤더와 숫자 표현 여유를 두고 UTF-8 JSON 기준으로 제한한다.
  static const int maxParamsBytes = 1500;

  static const int schemaVersion = 3;
  static const String eventIdKey = 'event_id';
  static const String eventSeqKey = 'event_seq';
  static const String schemaVersionKey = 'schema_version';
  static const String telemetryEnvKey = 'telemetry_env';
  static const String collectionKey = 'collection';
  static const String sampleRateKey = 'sample_rate';

  /// 예약 필드 이름. 호출자 값은 무시하고 사용자 파라미터 12개 한도에도 세지 않는다.
  /// params_dropped는 크기 제한으로 사용자 파라미터를 버렸을 때만 붙는다.
  static const String paramsDroppedKey = 'params_dropped';
  static const Set<String> _reserved = {
    eventIdKey,
    eventSeqKey,
    schemaVersionKey,
    telemetryEnvKey,
    collectionKey,
    sampleRateKey,
    paramsDroppedKey,
    ...PlayEventContext.reservedKeys,
  };

  final BackendGateway _gateway;
  final Ga4Analytics _ga4;
  final DateTime Function() _now;
  final Duration flushDelay;
  final int batchSize;
  final int maxQueue;
  final int maxQueueBytes;
  final Duration maxQueueAge;
  final String sessionId;
  final String channel;
  final TelemetryPolicy policy;

  /// 이 세션이 표본에 뽑혔는지. 세션 ID로 한 번 정해져 바뀌지 않는다.
  late final bool sessionSampled = policy.isSessionSampled(sessionId);
  int _sampledAccepted = 0;
  bool _qaLatched = false;

  /// 지금 이벤트에 붙는 환경. QA 스위치가 한 번이라도 켜졌으면 세션 끝까지 qa다.
  /// 이미 쌓인 행은 만들 때의 값을 유지하므로 재전송해도 바뀌지 않는다.
  TelemetryEnv get telemetryEnv {
    if (!_qaLatched) {
      try {
        _qaLatched = policy.qaProbe?.call() ?? false;
      } catch (_) {} // 감지 실패는 QA로 보지 않는다.
    }
    return _qaLatched ? TelemetryEnv.qa : policy.env;
  }

  String appVersion = '';

  late final TelemetryQueue _queue;
  Timer? _timer;
  Future<void>? _flushing;
  bool _observing = false;
  bool _disposed = false;
  int _seq = 0;
  int _failures = 0;
  DateTime? _retryAt;

  /// 저장 대기 중인 행 수(다른 사용자 소유라 보류한 행 포함).
  int get pendingCount => _queue.entries.length;

  /// 다음 전송을 시도할 수 있는 시각. null이면 바로 보낸다.
  DateTime? get retryAt => _retryAt;

  /// 예약된 자동 flush가 있는지(테스트 확인용).
  @visibleForTesting
  bool get hasScheduledFlush => _timer != null;

  void log(String name, [Map<String, Object?> params = const {}]) {
    _forwardGa4(name, params, null);
    _enqueue(name, params, null, TelemetryCollection.full);
  }

  /// 판과 시도 문맥이 붙는 플레이 이벤트. 문맥 필드는 사용자 파라미터 12개 한도에 세지 않는다.
  void logPlay(
    String name,
    PlayEventContext context, [
    Map<String, Object?> params = const {},
  ]) {
    _forwardGa4(name, params, context);
    _enqueue(name, params, context, TelemetryCollection.full);
  }

  /// 표본 행동 이벤트. 표본에 뽑힌 세션만, 세션당 policy.maxSampledEvents건까지 남긴다.
  /// 제한에 걸린 이벤트는 조용히 버리며 큐와 event_seq를 쓰지 않는다.
  void logBehavior(
    String name,
    Map<String, Object?> params, {
    PlayEventContext? context,
  }) {
    _forwardGa4(name, params, context);
    if (!sessionSampled || _sampledAccepted >= policy.maxSampledEvents) return;
    if (_enqueue(name, params, context, TelemetryCollection.sampled)) {
      _sampledAccepted++;
    }
  }

  void _forwardGa4(
    String name,
    Map<String, Object?> params,
    PlayEventContext? context,
  ) {
    try {
      _ga4.track(
        name,
        params,
        attemptSeq: context?.attemptSeq,
        appVersion: appVersion,
        schemaVersion: schemaVersion,
      );
    } catch (_) {} // GA4 실패는 내부 수집과 게임을 막지 않는다.
  }

  bool _enqueue(
    String name,
    Map<String, Object?> params,
    PlayEventContext? context,
    TelemetryCollection collection,
  ) {
    if (!_namePattern.hasMatch(name)) return false;
    // 오류 보고의 최근 행동. 백엔드 설정과 무관하게 이름, 시각, 허용 문맥만 남긴다.
    ErrorReporter.instance.noteEvent(name, params, context);
    if (!_gateway.isConfigured) return false;
    try {
      final now = _now();
      _queue.add(
        QueuedEvent(
          row: {
            'session_id': sessionId,
            'name': name,
            'params': _buildParams(params, context, collection),
            'app_version': appVersion,
            'channel': channel,
            'client_ts': now.toUtc().toIso8601String(),
          },
          owner: _gateway.currentUserId,
          queuedAt: now.millisecondsSinceEpoch,
        ),
      );
    } catch (_) {
      return false; // 로깅 실패는 게임 흐름을 막지 않는다. 이 이벤트만 버린다.
    }
    final user = _gateway.currentUserId;
    if (_queue.entries.where((e) => _sendable(e, user)).length >= batchSize) {
      unawaited(flush());
    } else if (_timer == null) {
      _arm(flushDelay);
    }
    return true;
  }

  /// 현재 사용자로 보낼 수 있는 행인지. 소유자가 확정되지 않은 이 세션의 행은 첫 인증에서 확정된다.
  bool _sendable(QueuedEvent e, String? user) =>
      e.owner == null ? e.sessionId == sessionId : e.owner == user;

  /// dispose 뒤에는 타이머를 만들지 않는다.
  void _arm(Duration delay) {
    _timer?.cancel();
    _timer = null;
    if (_disposed) return;
    _timer = Timer(delay, () {
      _timer = null;
      unawaited(flush());
    });
  }

  /// 보낼 수 있는 행을 배치로 보낸다. 동시에 부르면 진행 중인 같은 작업을 기다린다.
  /// backoff 중이면 보내지 않고 그 시각에 다시 시도하도록 예약한다.
  Future<void> flush() {
    final running = _flushing;
    if (running != null) return running;
    _timer?.cancel();
    _timer = null;
    return _flushing = _drain().whenComplete(() => _flushing = null);
  }

  Future<void> _drain() async {
    await _queue.ready;
    var allHeld = false;
    while (_queue.entries.isNotEmpty) {
      final retryAt = _retryAt;
      if (retryAt != null) {
        final wait = retryAt.difference(_now());
        // 기기 시계가 뒤로 가도 최대 대기보다 길게 막히지 않는다.
        if (wait > Duration.zero && wait <= maxBackoff + rateLimitBackoff) {
          _arm(wait);
          break;
        }
        _retryAt = null;
      }
      final (:held, :failure) = await _sendBatch();
      if (held) {
        // 남은 행은 모두 다른 사용자 소유다. 그 사용자로 돌아올 때까지 폴링하지 않고 보류한다.
        allHeld = true;
        break;
      } else if (failure == null) {
        _failures = 0;
      } else {
        _backoff(failure);
      }
    }
    await _queue.save();
    // 마지막 저장을 기다리는 동안 들어온 행은 다음 주기에 보낸다.
    if (!allHeld && _timer == null && _queue.entries.isNotEmpty) {
      _arm(flushDelay);
    }
  }

  /// 성공이나 버린 배치는 failure가 null이다. 보낼 행이 없으면 held.
  Future<({bool held, BackendFailure? failure})> _sendBatch() async {
    try {
      final session = await _gateway.ensureSession();
      if (!session.isSuccess) return (held: false, failure: session.failure!);
      final owner = _gateway.currentUserId;
      if (owner == null) return (held: true, failure: null);
      _queue.prune(); // 7일이 지난 행은 보내지 않는다.
      // 이 세션에서 인증 전에 쌓인 행은 첫 인증 사용자로 확정해 저장한 뒤 보낸다.
      // 다른 세션(이전 실행, 다른 탭)의 미확정 행은 누구의 것인지 모르므로 보내지 않는다.
      for (final e in _queue.entries) {
        if (e.owner == null && e.sessionId == sessionId) _queue.bind(e, owner);
      }
      // 소유자는 행에 저장된 값만 본다. 미확정 행은 위에서 이 세션 것만 확정했다.
      final batch = _queue.entries
          .where((e) => e.owner == owner)
          .take(batchSize)
          .toList();
      if (batch.isEmpty) return (held: true, failure: null);
      // 요청과 재인증 재시도 직전마다 게이트웨이가 같은 사용자인지 확인한다.
      final result = await _gateway.insert('game_events', [
        for (final e in batch) e.row,
      ], expectedUserId: owner);
      final failure = result.failure;
      if (failure == null ||
          failure == BackendFailure.rejected ||
          failure == BackendFailure.notFound) {
        // 성공 응답 뒤에만 지운다. 내용 거절은 다시 보내도 같으므로 버린다.
        _queue.removeIds({for (final e in batch) e.id});
        return (held: false, failure: null);
      }
      return (held: false, failure: failure);
    } catch (_) {
      // 게이트웨이 예외도 네트워크 실패로 본다.
      return (held: false, failure: BackendFailure.network);
    }
  }

  void _backoff(BackendFailure failure) {
    final exp = minBackoff * (1 << _failures.clamp(0, 10));
    var delay = exp > maxBackoff ? maxBackoff : exp;
    if (failure == BackendFailure.rateLimited && delay < rateLimitBackoff) {
      delay = rateLimitBackoff;
    }
    _failures++;
    _retryAt = _now().add(delay);
  }

  /// 앱이 백그라운드로 갈 때 남은 이벤트를 보낸다.
  void attachLifecycleFlush() {
    if (_observing) return;
    WidgetsBinding.instance.addObserver(this);
    _observing = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(flush());
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
  }

  /// 예약 필드 + 정제한 사용자 파라미터. 크기 초과 시 뒤쪽 파라미터부터 버리고 개수를 남긴다.
  Map<String, Object?> _buildParams(
    Map<String, Object?> params,
    PlayEventContext? context,
    TelemetryCollection collection,
  ) {
    final result = <String, Object?>{
      eventIdKey: uuidV4(),
      eventSeqKey: ++_seq,
      schemaVersionKey: schemaVersion,
      telemetryEnvKey: telemetryEnv.name,
      collectionKey: collection.name,
      sampleRateKey: policy.rateFor(collection),
      ...?context?.toParams(),
    };
    final user = _sanitize(params);
    var kept = 0;
    for (final entry in user.entries) {
      result[entry.key] = entry.value;
      if (_size(result) > maxParamsBytes) {
        result.remove(entry.key);
        break;
      }
      kept++;
    }
    if (kept < user.length) {
      result[paramsDroppedKey] = user.length - kept;
      while (kept > 0 && _size(result) > maxParamsBytes) {
        result.remove(user.keys.elementAt(--kept));
        result[paramsDroppedKey] = user.length - kept;
      }
    }
    return result;
  }

  static int _size(Object value) => utf8.encode(jsonEncode(value)).length;

  static Map<String, Object?> _sanitize(Map<String, Object?> params) {
    final result = <String, Object?>{};
    for (final entry in params.entries) {
      if (result.length >= _maxParams) break;
      if (_reserved.contains(entry.key) || !_namePattern.hasMatch(entry.key)) {
        continue;
      }
      final value = entry.value;
      if (value is num) {
        if (value.isFinite) result[entry.key] = value;
      } else if (value is bool) {
        result[entry.key] = value;
      } else if (value is String) {
        result[entry.key] = _cleanString(value);
      }
    }
    return result;
  }

  /// jsonb가 거절하는 NUL과 짝 없는 surrogate를 정리하고 코드포인트 64개로 자른다.
  static String _cleanString(String value) => String.fromCharCodes(
    value.runes
        .where((r) => r != 0)
        .map((r) => r >= 0xD800 && r <= 0xDFFF ? 0xFFFD : r)
        .take(_maxStringLength),
  );
}
