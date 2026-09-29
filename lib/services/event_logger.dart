import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../app_config.dart';
import 'backend/supabase_gateway.dart';
import 'play_event_context.dart';
import 'telemetry_policy.dart';

/// 내부 이벤트 로거(아이템 플랜 3.5차의 AnalyticsService 역할).
///
/// - 게임 코드는 SDK가 아니라 이 클래스만 부른다.
/// - Supabase가 설정되지 않은 빌드와 테스트에서는 아무것도 하지 않는다.
/// - 개인 식별 정보를 넣지 않는다. 값은 유한한 숫자, bool, 64자 이하 문자열만 12개까지 남긴다.
/// - params에는 호출자가 덮어쓸 수 없는 예약 필드(event_id, event_seq, schema_version)를
///   enqueue 때 한 번 붙인다. logPlay는 PlayEventContext의 run_id, round_seq, attempt_seq도
///   같은 방식으로 붙인다. 전역 현재 문맥은 없고 호출자가 문맥을 넘긴다. 재전송은 같은 행을 다시 보내므로 값이 유지된다.
/// - telemetry_env, collection, sample_rate도 예약 필드다. log/logPlay는 항상 collection=full, sample_rate=1.0이다.
///   logBehavior는 세션 단위 고정 표본(기본 10%)만 최대 maxSampledEvents건까지 남기고 collection=sampled를 붙인다.
///   서버 중복 제거와 영속 큐는 없다(PLAN-009 Step 4).
/// - 실패는 게임 흐름에 영향을 주지 않는다. 네트워크 실패만 큐에 되돌려 다시 보낸다.
class EventLogger with WidgetsBindingObserver {
  EventLogger({
    required SupabaseGateway gateway,
    this.flushDelay = const Duration(seconds: 5),
    this.batchSize = 20,
    this.maxQueue = 200,
    DateTime Function()? now,
    String? sessionId,
    String? channel,
    TelemetryPolicy? policy,
  }) : _gateway = gateway,
       _now = now ?? DateTime.now,
       sessionId = sessionId ?? uuidV4(),
       channel = channel ?? AppConfig.storeChannel.name,
       policy = policy ?? TelemetryPolicy.fromBuild();

  static final EventLogger instance = EventLogger(
    gateway: SupabaseGateway.instance,
  );

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

  final SupabaseGateway _gateway;
  final DateTime Function() _now;
  final Duration flushDelay;
  final int batchSize;
  final int maxQueue;
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

  final List<Map<String, Object?>> _queue = [];
  Timer? _timer;
  bool _flushing = false;
  bool _observing = false;
  int _seq = 0;

  int get pendingCount => _queue.length;

  void log(String name, [Map<String, Object?> params = const {}]) =>
      _enqueue(name, params, null, TelemetryCollection.full);

  /// 판과 시도 문맥이 붙는 플레이 이벤트. 문맥 필드는 사용자 파라미터 12개 한도에 세지 않는다.
  void logPlay(
    String name,
    PlayEventContext context, [
    Map<String, Object?> params = const {},
  ]) => _enqueue(name, params, context, TelemetryCollection.full);

  /// 표본 행동 이벤트. 표본에 뽑힌 세션만, 세션당 policy.maxSampledEvents건까지 남긴다.
  /// 제한에 걸린 이벤트는 조용히 버리며 큐와 event_seq를 쓰지 않는다.
  void logBehavior(
    String name,
    Map<String, Object?> params, {
    PlayEventContext? context,
  }) {
    if (!sessionSampled || _sampledAccepted >= policy.maxSampledEvents) return;
    if (_enqueue(name, params, context, TelemetryCollection.sampled)) {
      _sampledAccepted++;
    }
  }

  bool _enqueue(
    String name,
    Map<String, Object?> params,
    PlayEventContext? context,
    TelemetryCollection collection,
  ) {
    if (!_gateway.isConfigured || !_namePattern.hasMatch(name)) return false;
    try {
      _queue.add({
        'session_id': sessionId,
        'name': name,
        'params': _buildParams(params, context, collection),
        'app_version': appVersion,
        'channel': channel,
        'client_ts': _now().toUtc().toIso8601String(),
      });
    } catch (_) {
      return false; // 로깅 실패는 게임 흐름을 막지 않는다. 이 이벤트만 버린다.
    }
    _trimQueue();
    if (_queue.length >= batchSize) {
      unawaited(flush());
    } else {
      _timer ??= Timer(flushDelay, () {
        _timer = null;
        unawaited(flush());
      });
    }
    return true;
  }

  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    if (_flushing || _queue.isEmpty) return;
    _flushing = true;
    final batch = _queue.take(batchSize).toList();
    _queue.removeRange(0, batch.length);
    try {
      final result = await _gateway.insert('game_events', batch);
      if (!result.isSuccess && _shouldRetry(result.failure!)) {
        _queue.insertAll(0, batch);
        _trimQueue();
        return;
      }
    } finally {
      _flushing = false;
    }
    if (_queue.isNotEmpty) await flush();
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
    _timer?.cancel();
    _timer = null;
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
  }

  bool _shouldRetry(BackendFailure failure) =>
      failure == BackendFailure.network ||
      failure == BackendFailure.server ||
      failure == BackendFailure.unauthorized;

  void _trimQueue() {
    if (_queue.length > maxQueue) {
      _queue.removeRange(0, _queue.length - maxQueue);
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
