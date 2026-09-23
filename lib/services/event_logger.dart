import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';

import '../app_config.dart';
import 'backend/supabase_gateway.dart';

/// 내부 이벤트 로거(아이템 플랜 3.5차의 AnalyticsService 역할).
///
/// - 게임 코드는 SDK가 아니라 이 클래스만 부른다.
/// - Supabase가 설정되지 않은 빌드와 테스트에서는 아무것도 하지 않는다.
/// - 개인 식별 정보를 넣지 않는다. 값은 숫자, bool, 64자 이하 문자열만 12개까지 남긴다.
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
  }) : _gateway = gateway,
       _now = now ?? DateTime.now,
       sessionId = sessionId ?? _uuidV4(),
       channel = channel ?? AppConfig.storeChannel.name;

  static final EventLogger instance = EventLogger(
    gateway: SupabaseGateway.instance,
  );

  static final RegExp _namePattern = RegExp(r'^[a-z][a-z0-9_]{0,39}$');
  static const int _maxParams = 12;
  static const int _maxStringLength = 64;

  final SupabaseGateway _gateway;
  final DateTime Function() _now;
  final Duration flushDelay;
  final int batchSize;
  final int maxQueue;
  final String sessionId;
  final String channel;
  String appVersion = '';

  final List<Map<String, Object?>> _queue = [];
  Timer? _timer;
  bool _flushing = false;
  bool _observing = false;

  int get pendingCount => _queue.length;

  void log(String name, [Map<String, Object?> params = const {}]) {
    if (!_gateway.isConfigured || !_namePattern.hasMatch(name)) return;
    _queue.add({
      'session_id': sessionId,
      'name': name,
      'params': _sanitize(params),
      'app_version': appVersion,
      'channel': channel,
      'client_ts': _now().toUtc().toIso8601String(),
    });
    _trimQueue();
    if (_queue.length >= batchSize) {
      unawaited(flush());
    } else {
      _timer ??= Timer(flushDelay, () {
        _timer = null;
        unawaited(flush());
      });
    }
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

  static Map<String, Object?> _sanitize(Map<String, Object?> params) {
    final result = <String, Object?>{};
    for (final entry in params.entries) {
      if (result.length >= _maxParams) break;
      if (!_namePattern.hasMatch(entry.key)) continue;
      final value = entry.value;
      if (value is num || value is bool) {
        result[entry.key] = value;
      } else if (value is String) {
        result[entry.key] = value.length > _maxStringLength
            ? value.substring(0, _maxStringLength)
            : value;
      }
    }
    return result;
  }

  static String _uuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
