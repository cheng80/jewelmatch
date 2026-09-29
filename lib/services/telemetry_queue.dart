import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 텔레메트리 큐 저장 매체. 키 단위 문자열만 다룬다.
abstract interface class TelemetryQueueStore {
  /// [prefix]로 시작하는 모든 키와 값.
  Future<Map<String, String>> readAll(String prefix);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

/// 테스트 기본 저장소. 같은 인스턴스를 넘기면 앱 재시작과 다중 탭을 흉내 낼 수 있다.
class MemoryTelemetryQueueStore implements TelemetryQueueStore {
  final Map<String, String> values = {};

  @override
  Future<Map<String, String>> readAll(String prefix) async => {
    for (final e in values.entries)
      if (e.key.startsWith(prefix)) e.key: e.value,
  };

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);
}

/// 운영 저장소. 웹에서는 localStorage라 같은 브라우저의 탭이 공유한다.
class PrefsTelemetryQueueStore implements TelemetryQueueStore {
  const PrefsTelemetryQueueStore();

  @override
  Future<Map<String, String>> readAll(String prefix) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // 다른 탭이 쓴 값을 본다.
    return {
      for (final key in prefs.getKeys())
        if (key.startsWith(prefix) && prefs.get(key) is String)
          key: prefs.getString(key)!,
    };
  }

  @override
  Future<void> write(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(key, value)) {
      throw StateError('Telemetry queue was not persisted');
    }
  }

  @override
  Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}

/// 큐의 한 행. [row]는 전송 본문 그대로이며 저장과 복원 후에도 바뀌지 않는다.
class QueuedEvent {
  QueuedEvent({required this.row, required this.owner, required this.queuedAt})
    : id = (row['params']! as Map)['event_id']! as String,
      bytes = utf8.encode(jsonEncode(row)).length;

  final Map<String, Object?> row;

  /// 이 행을 보낼 수 있는 백엔드 사용자 ID. null이면 인증 전에 쌓였고 아직 확정되지 않았다.
  /// 확정은 만든 세션의 첫 인증에서 한 번만 하며 이후 바꾸지 않는다.
  String? owner;
  final int queuedAt; // epoch ms
  final String id;
  final int bytes;

  String? get sessionId => row['session_id'] as String?;

  String encode() => jsonEncode({
    'v': TelemetryQueue.version,
    'o': owner,
    't': queuedAt,
    'r': row,
  });

  /// 저장 값 하나를 해석한다. 형식이 어긋나면 어디가 깨졌든 null이다.
  static QueuedEvent? tryParse(String raw) {
    try {
      final value = jsonDecode(raw);
      // 다른 버전 값은 해석하지 않는다(호출자가 보존 여부를 정한다).
      if (value is! Map || value['v'] != TelemetryQueue.version) return null;
      final row = value['r'];
      final owner = value['o'];
      final t = value['t'];
      if (row is! Map<String, dynamic> ||
          (owner != null && (owner is! String || owner.isEmpty)) ||
          t is! int) {
        return null;
      }
      final params = row['params'];
      final id = params is Map ? params['event_id'] : null;
      if (row['name'] is! String ||
          row['session_id'] is! String ||
          row['client_ts'] is! String ||
          params is! Map<String, dynamic> ||
          id is! String ||
          id.isEmpty) {
        return null;
      }
      return QueuedEvent(row: row, owner: owner as String?, queuedAt: t);
    } catch (_) {
      return null;
    }
  }
}

/// 백엔드 범위별 영속 이벤트 큐. 이벤트 하나를 불변 키 하나에 저장한다.
///
/// - 키: `telemetry.queue.v2.<scope>.<event_id>`. 행의 내용은 쓴 뒤 바뀌지 않는다(소유자 확정만 다시 쓴다).
/// - 키는 성공 전송, 내용 거절, 용량/기한 초과로만 지운다. 다른 탭이나 이전 실행의 키를 통째로 옮기거나
///   지우지 않으므로 살아 있는 탭이 복원 뒤에 쓴 행을 잃지 않는다. 같은 행을 두 탭이 보내면
///   중복 전송만 생기고 서버 event_id 중복 제거에 맡긴다.
/// - 저장소 작업은 순서대로 한 줄로 실행해 쓰기 뒤 지우기가 뒤바뀌지 않는다.
/// - 저장 실패, 손상은 게임을 막지 않는다. 손상 키는 지우고 모르는 버전 값은 남긴다.
class TelemetryQueue {
  TelemetryQueue({
    required TelemetryQueueStore store,
    required String scope,
    required this.maxRows,
    required this.maxBytes,
    required this.maxAge,
    required int Function() nowMs,
  }) : _store = store,
       _nowMs = nowMs,
       prefix = '$keyRoot${Uri.encodeComponent(scope)}.';

  static const int version = 2;
  static const String keyRoot = 'telemetry.queue.v$version.';
  static final RegExp _idPattern = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  final TelemetryQueueStore _store;
  final int Function() _nowMs;
  final String prefix;
  final int maxRows;
  final int maxBytes;
  final Duration maxAge;

  final List<QueuedEvent> entries = [];
  int _bytes = 0;
  Future<void>? _restore;
  Future<void> _tail = Future.value();
  final Set<String> _unsaved = {};

  /// 아직 저장하지 못한 행이 있는지. [save]에서 다시 시도한다.
  bool get hasUnsaved => _unsaved.isNotEmpty;

  String keyFor(String id) => '$prefix$id';

  /// 저장된 행을 한 번만 불러온다. 실패해도 완료된다.
  Future<void> get ready => _restore ??= _load();

  void add(QueuedEvent event) {
    unawaited(ready);
    entries.add(event);
    _bytes += event.bytes;
    _put(event);
    _trim();
  }

  /// 소유자를 확정하고 저장한다.
  void bind(QueuedEvent event, String owner) {
    event.owner = owner;
    _put(event);
  }

  void removeIds(Set<String> ids) {
    if (ids.isEmpty) return;
    final gone = <String>[];
    entries.removeWhere((e) {
      if (!ids.contains(e.id)) return false;
      _bytes -= e.bytes;
      gone.add(e.id);
      return true;
    });
    _delete(gone);
  }

  /// 대기 중인 저장소 작업이 끝날 때까지 기다린다. 저장 못 한 행은 다시 쓴다.
  Future<void> save() async {
    await ready;
    for (final e in entries) {
      if (_unsaved.contains(e.id)) _put(e);
    }
    Future<void> tail;
    do {
      tail = _tail;
      await tail;
    } while (!identical(tail, _tail));
  }

  void _put(QueuedEvent event) {
    final raw = event.encode();
    _enqueueOp(() async {
      try {
        await _store.write(keyFor(event.id), raw);
        _unsaved.remove(event.id);
      } catch (_) {
        _unsaved.add(event.id); // 메모리 큐는 유지한다.
      }
    });
  }

  void _delete(List<String> ids) {
    if (ids.isEmpty) return;
    _enqueueOp(() async {
      for (final id in ids) {
        _unsaved.remove(id);
        try {
          await _store.remove(keyFor(id));
        } catch (_) {} // 남은 키는 다음 실행에서 다시 보내 중복이 될 뿐이다.
      }
    });
  }

  void _enqueueOp(Future<void> Function() op) {
    _tail = _tail.then((_) => op());
  }

  Future<void> _load() async {
    final Map<String, String> all;
    try {
      all = await _store.readAll(prefix);
    } catch (_) {
      return; // 읽기 실패: 이번 실행은 메모리 큐로만 동작한다.
    }
    final restored = <QueuedEvent>[];
    final corrupt = <String>[];
    for (final MapEntry(key: k, value: raw) in all.entries) {
      final id = k.substring(prefix.length);
      if (!_idPattern.hasMatch(id)) continue; // 다른 범위의 키
      final event = QueuedEvent.tryParse(raw);
      if (event == null || event.id != id) {
        if (!_isOtherVersion(raw)) corrupt.add(id);
        continue;
      }
      restored.add(event);
    }
    _delete(corrupt);
    // 같은 시각이면 원래 순서를 유지한다(List.sort는 안정 정렬이 아니다).
    final order = {for (final (i, e) in restored.indexed) e: i};
    restored.sort(
      (a, b) => a.queuedAt != b.queuedAt
          ? a.queuedAt.compareTo(b.queuedAt)
          : order[a]!.compareTo(order[b]!),
    );
    final known = {for (final e in entries) e.id};
    final older = [
      for (final e in restored)
        if (known.add(e.id)) e,
    ];
    entries.insertAll(0, older);
    _bytes = entries.fold(0, (sum, e) => sum + e.bytes);
    _trim();
  }

  static bool _isOtherVersion(String raw) {
    try {
      final value = jsonDecode(raw);
      return value is Map && value['v'] is int && value['v'] != version;
    } catch (_) {
      return false;
    }
  }

  /// 보관 기한이 지난 행을 지운다. 오래 켜 둔 앱에서도 전송 직전에 부른다.
  void prune() => _trim();

  /// 오래된 행과 상한 초과분을 앞(오래된 쪽)부터 버린다.
  // ponytail: 만료는 앞에서부터 연속 구간만 본다. 기기 시계가 크게 뒤로 가면 뒤쪽 만료 행이 상한까지 남는다.
  void _trim() {
    final cutoff = _nowMs() - maxAge.inMilliseconds;
    var drop = 0;
    var bytes = _bytes;
    while (drop < entries.length &&
        (entries[drop].queuedAt < cutoff ||
            entries.length - drop > maxRows ||
            bytes > maxBytes)) {
      bytes -= entries[drop].bytes;
      drop++;
    }
    if (drop == 0) return;
    final gone = [for (final e in entries.take(drop)) e.id];
    entries.removeRange(0, drop);
    _bytes = bytes;
    _delete(gone);
  }
}
