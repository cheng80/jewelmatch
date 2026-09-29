import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stonematch/services/backend/backend_gateway.dart';
import 'package:stonematch/services/backend/pocketbase_config.dart';
import 'package:stonematch/services/backend/pocketbase_gateway.dart';
import 'package:stonematch/services/event_logger.dart';
import 'package:stonematch/services/telemetry_policy.dart';
import 'package:stonematch/services/telemetry_queue.dart';

final _start = DateTime.utc(2026, 9, 29, 12);
var _clock = _start;
const _policy = TelemetryPolicy(env: TelemetryEnv.test);
const _scope = 'https://pb.example';
const _sessionA = '00000000-0000-4000-8000-00000000000a';
const _sessionB = '00000000-0000-4000-8000-00000000000b';
const _sessionC = '00000000-0000-4000-8000-00000000000c';

/// 사용자 전환을 직접 조작하는 게이트웨이. insert 때의 사용자와 본문을 기록한다.
class _FakeGateway implements BackendGateway {
  _FakeGateway({this.user = 'user-a'});

  String? user;
  final sent = <({String? user, String body})>[];
  final attempted = <String>[];
  final expected = <String?>[];
  Future<BackendResult<Object?>> Function() respond = () async =>
      const BackendResult.success(null);
  int insertCalls = 0;
  int sessionCalls = 0;

  List<String> get sentNames => [
    for (final s in sent)
      for (final row in jsonDecode(s.body) as List)
        (row as Map)['name'] as String,
  ];

  @override
  bool get isConfigured => true;
  @override
  String? get currentUserId => user;
  @override
  Future<BackendResult<Object?>> ensureSession() async {
    sessionCalls++;
    return const BackendResult.success(null);
  }

  @override
  Future<BackendResult<Object?>> insert(
    String table,
    List<Map<String, Object?>> rows, {
    String? expectedUserId,
  }) async {
    insertCalls++;
    expected.add(expectedUserId);
    final atUser = user;
    final body = jsonEncode(rows);
    attempted.add(body);
    final result = await respond();
    if (result.isSuccess) sent.add((user: atUser, body: body));
    return result;
  }

  @override
  Future<BackendResult<Object?>> rpc(
    String function,
    Map<String, Object?> params, {
    bool requireAuth = true,
  }) => throw UnimplementedError();
  @override
  Future<BackendResult<Object?>> select(String pathAndQuery) =>
      throw UnimplementedError();
}

_FakeGateway _offline({String? user = 'user-a'}) =>
    _FakeGateway(user: user)
      ..respond = () async =>
          const BackendResult.failure(BackendFailure.network);

class _FailingStore extends MemoryTelemetryQueueStore {
  bool failWrite = false;
  bool failRead = false;
  @override
  Future<Map<String, String>> readAll(String prefix) async {
    if (failRead) throw StateError('read');
    return super.readAll(prefix);
  }

  @override
  Future<void> write(String key, String value) async {
    if (failWrite) throw StateError('quota');
    return super.write(key, value);
  }
}

/// readAll의 스냅샷을 찍은 뒤 [gate]가 열릴 때까지 돌려주지 않는다(다른 탭 경합 재현).
class _GatedStore extends MemoryTelemetryQueueStore {
  Completer<void>? gate;
  @override
  Future<Map<String, String>> readAll(String prefix) async {
    final snapshot = await super.readAll(prefix);
    await gate?.future;
    return snapshot;
  }
}

EventLogger _logger(
  BackendGateway gateway,
  TelemetryQueueStore store, {
  String sessionId = _sessionA,
  String scope = _scope,
  int batchSize = 20,
  int maxQueue = 200,
  int maxQueueBytes = 256 * 1024,
}) {
  final logger = EventLogger(
    gateway: gateway,
    flushDelay: const Duration(hours: 1),
    batchSize: batchSize,
    maxQueue: maxQueue,
    maxQueueBytes: maxQueueBytes,
    now: () => _clock,
    sessionId: sessionId,
    channel: 'web',
    policy: _policy,
    store: store,
    storageScope: scope,
  );
  addTearDown(logger.dispose);
  return logger;
}

String _prefix([String scope = _scope]) =>
    '${TelemetryQueue.keyRoot}${Uri.encodeComponent(scope)}.';

/// 저장소에 남은 행(쓴 순서)과 소유자.
List<({String name, String? owner})> _stored(
  MemoryTelemetryQueueStore store, [
  String scope = _scope,
]) => [
  for (final e in store.values.entries)
    if (e.key.startsWith(_prefix(scope)) &&
        !e.key.substring(_prefix(scope).length).contains('.'))
      (
        name: ((jsonDecode(e.value) as Map)['r'] as Map)['name'] as String,
        owner: (jsonDecode(e.value) as Map)['o'] as String?,
      ),
];

List<String> _storedNames(
  MemoryTelemetryQueueStore store, [
  String scope = _scope,
]) => _stored(store, scope).map((e) => e.name).toList();

Map<String, Object?> _auth(String userId) => {
  'token': 't-$userId',
  'record': {'id': userId},
  'expires_in': 86400,
};

/// 실제 PocketBase 게이트웨이의 상태 코드 매핑을 거친다. 이벤트 요청 본문을 [bodies]에 모은다.
PocketBaseGateway _pocketBase(
  Future<http.Response> Function() events, [
  List<String>? bodies,
]) => PocketBaseGateway(
  config: const PocketBaseConfig(url: _scope),
  now: () => _clock,
  client: MockClient((request) async {
    if (request.url.path.endsWith('/auth/guest')) {
      return http.Response(jsonEncode(_auth('user-a')), 200);
    }
    bodies?.add(request.body);
    return events();
  }),
);

void main() {
  setUp(() => _clock = _start);

  group('응답별 재시도', () {
    Future<(EventLogger, List<int>)> run(int status) async {
      final calls = <int>[];
      final logger = _logger(
        _pocketBase(() async {
          calls.add(status);
          return http.Response('', status);
        }),
        MemoryTelemetryQueueStore(),
      );
      logger.log('round_start');
      await logger.flush();
      return (logger, calls);
    }

    test('204는 전체 수락으로 보고 지운다', () async {
      final (logger, _) = await run(204);
      expect(logger.pendingCount, 0);
      expect(logger.retryAt, isNull);
    });

    test('400은 내용 거절이라 그 배치를 버리고 backoff하지 않는다', () async {
      final (logger, _) = await run(400);
      expect(logger.pendingCount, 0);
      expect(logger.retryAt, isNull);
    });

    test('401은 남기고 backoff한다', () async {
      final (logger, _) = await run(401);
      expect(logger.pendingCount, 1);
      expect(logger.retryAt, _start.add(EventLogger.minBackoff));
    });

    test('429는 60초 전에는 다시 보내지 않고 이후 같은 행을 보낸다', () async {
      var status = 429;
      final bodies = <String>[];
      final logger = _logger(
        _pocketBase(() async => http.Response('', status), bodies),
        MemoryTelemetryQueueStore(),
      );
      logger.log('round_start');
      await logger.flush();
      expect(logger.retryAt, _start.add(const Duration(seconds: 60)));

      status = 204;
      _clock = _start.add(const Duration(seconds: 59));
      await logger.flush();
      expect(bodies, hasLength(1));
      expect(logger.pendingCount, 1);

      _clock = _start.add(const Duration(seconds: 60));
      await logger.flush();
      expect(bodies, hasLength(2));
      expect(bodies[1], bodies[0]);
      expect(logger.pendingCount, 0);
    });

    test('5xx는 5초부터 두 배씩 늘고 5분에서 멈춘다', () async {
      final (logger, _) = await run(503);
      final waits = <Duration>[logger.retryAt!.difference(_clock)];
      for (var i = 0; i < 8; i++) {
        _clock = logger.retryAt!;
        await logger.flush();
        waits.add(logger.retryAt!.difference(_clock));
      }
      expect(waits.map((d) => d.inSeconds), [
        5,
        10,
        20,
        40,
        80,
        160,
        300,
        300,
        300,
      ]);
      expect(logger.pendingCount, 1);
    });

    test('네트워크 예외(게이트웨이 throw 포함)는 잡아서 남기고 성공 뒤에 지운다', () async {
      final gateway = _FakeGateway()
        ..respond = () async => throw StateError('socket');
      final logger = _logger(gateway, MemoryTelemetryQueueStore());
      logger.log('round_start');
      await expectLater(logger.flush(), completes);
      expect(logger.pendingCount, 1);

      gateway.respond = () async => const BackendResult.success(null);
      _clock = logger.retryAt!;
      await logger.flush();
      expect(logger.pendingCount, 0);
      expect(logger.retryAt, isNull);
    });

    test('기기 시계가 뒤로 가도 최대 대기보다 길게 막히지 않는다', () async {
      final (logger, calls) = await run(503);
      _clock = _start.subtract(const Duration(days: 1));
      await logger.flush();
      expect(calls, hasLength(2));
    });
  });

  group('앱 재시작 복원', () {
    test('보내지 못한 행은 다음 실행에서 같은 본문으로 다시 보낸다', () async {
      final store = MemoryTelemetryQueueStore();
      final first = _offline();
      final before = _logger(first, store);
      before.log('round_start', {'score': 7, 'rate': 0.5});
      before.log('round_end', {'big': 9007199254740991});
      await before.flush();
      final original = first.attempted.single;

      final second = _FakeGateway();
      final after = _logger(second, store, sessionId: _sessionB);
      await after.flush();

      expect(second.sent.single.body, original);
      expect(after.pendingCount, 0);
      expect(store.values, isEmpty);
    });

    test('복원 전에 들어온 이벤트를 잃지 않고 저장된 행 뒤에 합친다', () async {
      final store = MemoryTelemetryQueueStore();
      final before = _logger(_offline(), store);
      before.log('old_event');
      await before.flush();

      final gateway = _FakeGateway();
      final after = _logger(gateway, store, sessionId: _sessionB);
      after.log('new_event'); // 복원이 끝나기 전의 동기 enqueue
      expect(after.pendingCount, 1);
      await after.flush();

      expect(gateway.sentNames, ['old_event', 'new_event']);
    });

    test('성공 응답 뒤에만 저장소에서도 지운다', () async {
      final store = MemoryTelemetryQueueStore();
      final gateway = _FakeGateway();
      final pending = Completer<BackendResult<Object?>>();
      gateway.respond = () => pending.future;
      final logger = _logger(gateway, store);
      logger.log('round_start');
      final flushing = logger.flush();
      await pumpEventQueue();
      expect(_storedNames(store), ['round_start']);

      pending.complete(const BackendResult.success(null));
      await flushing;
      expect(store.values, isEmpty);
    });
  });

  group('소유자 격리', () {
    test('사용자가 바뀌면 이전 사용자 행을 새 사용자로 보내지 않는다', () async {
      final gateway = _offline();
      final logger = _logger(gateway, MemoryTelemetryQueueStore());
      logger.log('a_event');
      await logger.flush();

      gateway
        ..user = 'user-b'
        ..respond = () async => const BackendResult.success(null);
      logger.log('b_event');
      _clock = logger.retryAt!;
      await logger.flush();

      expect(gateway.sent.map((s) => s.user), ['user-b']);
      expect(gateway.sentNames, ['b_event']);
      expect(gateway.expected.last, 'user-b');
      expect(logger.pendingCount, 1); // a_event 보류

      gateway.user = 'user-a';
      await logger.flush();
      expect(gateway.sent.last.user, 'user-a');
      expect(gateway.expected.last, 'user-a');
      expect(gateway.sentNames, ['b_event', 'a_event']);
    });

    test('재시작 뒤 다른 사용자면 이전 큐를 보류하고 원래 사용자면 보낸다', () async {
      final store = MemoryTelemetryQueueStore();
      final first = _logger(_offline(), store);
      first.log('a_event');
      await first.flush();

      final b = _FakeGateway(user: 'user-b');
      final second = _logger(b, store, sessionId: _sessionB);
      second.log('b_event');
      await second.flush();
      expect(b.sentNames, ['b_event']);
      expect(second.pendingCount, 1);
      expect(_storedNames(store), ['a_event']);

      final again = _FakeGateway();
      final third = _logger(again, store, sessionId: _sessionC);
      await third.flush();
      expect(again.sentNames, ['a_event']);
      expect(store.values, isEmpty);
    });

    test('인증 전 행은 첫 인증 사용자로 확정 저장하고 이후 다른 사용자로 보내지 않는다', () async {
      final store = MemoryTelemetryQueueStore();
      final gateway = _offline(user: null);
      final logger = _logger(gateway, store);
      logger.log('boot_event');
      await pumpEventQueue();
      expect(_stored(store).single.owner, isNull);

      gateway.user = 'user-a'; // 첫 인증
      await logger.flush(); // 전송 실패
      expect(_stored(store).single.owner, 'user-a');
      expect(gateway.expected.single, 'user-a');

      gateway
        ..user = 'user-b'
        ..respond = () async => const BackendResult.success(null);
      _clock = logger.retryAt!;
      await logger.flush();
      expect(gateway.sent, isEmpty);
      expect(logger.pendingCount, 1);
      expect(_stored(store).single.owner, 'user-a');
    });

    test('다른 세션의 미확정 행은 누구에게도 보내지 않는다', () async {
      final store = MemoryTelemetryQueueStore();
      final early = _logger(_offline(user: null), store);
      early.log('orphan');
      await early.flush(); // 인증 전이라 보내지 않고 저장만 한다.
      expect(_stored(store).single.owner, isNull);

      final gateway = _FakeGateway();
      final next = _logger(gateway, store, sessionId: _sessionB);
      next.log('mine');
      await next.flush();
      expect(gateway.sentNames, ['mine']);
      expect(_stored(store).single, (name: 'orphan', owner: null));
      expect(next.hasScheduledFlush, isFalse);
    });

    test('다른 백엔드 범위의 큐는 읽지 않는다', () async {
      final store = MemoryTelemetryQueueStore();
      final old = _logger(_offline(), store, scope: 'https://old.example');
      old.log('old_backend');
      await old.flush();
      // 범위 이름이 접두어로 겹쳐도 섞이지 않는다.
      final nested = _logger(_offline(), store, scope: 'https://old.example.x');
      nested.log('nested_backend');
      await nested.flush();

      final gateway = _FakeGateway();
      final logger = _logger(
        gateway,
        store,
        sessionId: _sessionB,
        scope: 'https://old.example',
      );
      await logger.flush();
      expect(gateway.sentNames, ['old_backend']);
      expect(_storedNames(store, 'https://old.example.x'), ['nested_backend']);
    });

    test('다른 사용자 행만 남으면 폴링 타이머를 만들지 않는다', () async {
      final gateway = _offline();
      final logger = _logger(gateway, MemoryTelemetryQueueStore());
      logger.log('a_event');
      await logger.flush();
      gateway.user = 'user-b';
      _clock = logger.retryAt!;
      await logger.flush();

      expect(logger.pendingCount, 1);
      expect(logger.hasScheduledFlush, isFalse);
    });
  });

  group('PocketBase 재인증 중 사용자 변경', () {
    test('401 재인증으로 다른 사용자가 되면 그 계정으로 다시 보내지 않는다', () async {
      var authCount = 0;
      final eventTokens = <String?>[];
      final gateway = PocketBaseGateway(
        config: const PocketBaseConfig(url: _scope),
        now: () => _clock,
        client: MockClient((request) async {
          if (request.url.path.endsWith('/auth/guest')) {
            // 보존 삭제 등으로 같은 기기가 새 사용자 ID를 받는 상황
            final id = authCount++ == 0 ? 'user-a' : 'user-b';
            return http.Response(jsonEncode(_auth(id)), 200);
          }
          eventTokens.add(request.headers['Authorization']);
          return http.Response('', eventTokens.length == 1 ? 401 : 204);
        }),
      );
      await gateway.ensureSession();
      final logger = _logger(gateway, MemoryTelemetryQueueStore());
      logger.log('a_event');
      await logger.flush();

      expect(eventTokens, ['t-user-a']); // user-b 토큰으로는 보내지 않았다.
      expect(gateway.currentUserId, 'user-b');
      expect(logger.pendingCount, 1);

      _clock = _clock.add(const Duration(minutes: 20));
      await logger.flush();
      expect(eventTokens, ['t-user-a']);
      expect(logger.pendingCount, 1);
    });
  });

  group('동시 flush와 dispose', () {
    test('동시에 불러도 한 번만 보내고 전송 중 추가된 행을 잃지 않는다', () async {
      final store = MemoryTelemetryQueueStore();
      final gateway = _FakeGateway();
      final gate = Completer<void>();
      gateway.respond = () async {
        await gate.future;
        return const BackendResult.success(null);
      };
      final logger = _logger(gateway, store);
      logger.log('first');
      final a = logger.flush();
      final b = logger.flush();
      await pumpEventQueue();
      logger.log('during_flight');
      await pumpEventQueue();
      expect(gateway.insertCalls, 1);
      expect(_storedNames(store), ['first', 'during_flight']);

      gate.complete();
      await Future.wait([a, b]);
      expect(gateway.sentNames, ['first', 'during_flight']);
      expect(logger.pendingCount, 0);
      expect(store.values, isEmpty);
    });

    test('전송 중 상한으로 잘린 행이 있어도 새 행을 지우지 않는다', () async {
      final gateway = _FakeGateway();
      final gate = Completer<void>();
      gateway.respond = () async {
        await gate.future;
        return const BackendResult.success(null);
      };
      final logger = _logger(gateway, MemoryTelemetryQueueStore(), maxQueue: 2);
      logger.log('e0');
      final flushing = logger.flush();
      await pumpEventQueue();
      logger.log('e1');
      logger.log('e2'); // e0가 잘린다
      gate.complete();
      await flushing;
      expect(gateway.sentNames, ['e0', 'e1', 'e2']);
    });

    test('dispose 뒤 끝난 flush는 재시도 타이머를 만들지 않는다', () async {
      final gateway = _FakeGateway();
      final gate = Completer<void>();
      gateway.respond = () async {
        await gate.future;
        return const BackendResult.failure(BackendFailure.server);
      };
      final logger = _logger(gateway, MemoryTelemetryQueueStore());
      logger.log('round_start');
      final flushing = logger.flush();
      await pumpEventQueue();
      logger.dispose();
      gate.complete();
      await flushing;
      expect(logger.retryAt, isNotNull);
      expect(logger.hasScheduledFlush, isFalse);

      logger.log('after_dispose');
      expect(logger.hasScheduledFlush, isFalse);
    });
  });

  group('저장 실패와 손상', () {
    test('쓰기 실패는 게임을 막지 않고 메모리 큐로 보낸다', () async {
      final store = _FailingStore()..failWrite = true;
      final gateway = _FakeGateway();
      final logger = _logger(gateway, store);
      expect(() => logger.log('round_start'), returnsNormally);
      await logger.flush();
      expect(gateway.sentNames, ['round_start']);
    });

    test('쓰기 실패 중 보내지 못한 행은 저장이 회복되면 다시 저장한다', () async {
      final store = _FailingStore()..failWrite = true;
      final logger = _logger(_offline(), store);
      logger.log('round_start');
      await logger.flush();
      expect(store.values, isEmpty);

      store.failWrite = false;
      await logger.flush(); // backoff 중이어도 저장은 다시 시도한다.
      expect(_storedNames(store), ['round_start']);
    });

    test('읽기 실패는 이번 실행을 메모리 큐로 동작시킨다', () async {
      final store = _FailingStore()..failRead = true;
      final gateway = _FakeGateway();
      final logger = _logger(gateway, store);
      logger.log('round_start');
      await logger.flush();
      expect(gateway.sentNames, ['round_start']);
    });

    test('중첩까지 깨진 값은 그 키만 건너뛰고 나머지는 복원하며 모르는 버전은 남긴다', () async {
      final store = MemoryTelemetryQueueStore();
      Map<String, Object?> row(String name, Object? params) => {
        'session_id': 's',
        'name': name,
        'params': params,
        'app_version': '',
        'channel': 'web',
        'client_ts': '2026-09-29T12:00:00.000Z',
      };
      String value(Object? r, {Object? o = 'user-a', Object? t}) => jsonEncode({
        'v': 2,
        'o': o,
        't': t ?? _start.millisecondsSinceEpoch,
        'r': r,
      });
      final p = _prefix();
      store.values['${p}e-1'] = value(row('kept', {'event_id': 'e-1'}));
      store.values['${p}bad-json'] = '{not json';
      store.values['${p}not-map'] = '[1, 2]';
      store.values['${p}id-int'] = value(row('x', {'event_id': 123}));
      store.values['${p}params-list'] = value(row('x', [1]));
      store.values['${p}row-null'] = value(null);
      store.values['${p}owner-map'] = value(
        row('x', {'event_id': 'owner-map'}),
        o: {'id': 1},
      );
      store.values['${p}t-double'] = value(
        row('x', {'event_id': 't-double'}),
        t: 1.5,
      );
      store.values['${p}id-mismatch'] = value(row('x', {'event_id': 'other'}));
      store.values['${p}name-null'] = value({
        ...row('x', {'event_id': 'name-null'}),
        'name': null,
      });
      store.values['${p}future'] = jsonEncode({'v': 3, 'anything': true});
      // 형식은 맞지만 버전이 다른 행은 해석하지 않고 남긴다.
      final v1Row = jsonEncode({
        'v': 1,
        'o': 'user-a',
        't': _start.millisecondsSinceEpoch,
        'r': row('old_format', {'event_id': 'v1-row'}),
      });
      store.values['${p}v1-row'] = v1Row;
      store.values['${p}no-version'] = jsonEncode({
        'o': 'user-a',
        't': _start.millisecondsSinceEpoch,
        'r': row('x', {'event_id': 'no-version'}),
      });
      store.values['${p}e-2'] = value(row('kept2', {'event_id': 'e-2'}));

      final gateway = _FakeGateway();
      final logger = _logger(gateway, store);
      await logger.flush();

      expect(gateway.sentNames, ['kept', 'kept2']);
      expect(store.values.keys, ['${p}future', '${p}v1-row']);
    });
  });

  group('다중 탭', () {
    test('다른 탭이 복원한 뒤 쓴 행은 그 탭이 닫혀도 지워지지 않는다', () async {
      final store = _GatedStore();
      final tabA = _logger(_offline(), store);
      tabA.log('a1');
      await tabA.flush();

      // 탭 B가 저장소를 읽는 동안(스냅샷 이후) 탭 A가 새 행을 쓰고 닫힌다.
      store.gate = Completer<void>();
      final online = _FakeGateway();
      final tabB = _logger(online, store, sessionId: _sessionB);
      final restoring = tabB.flush();
      await pumpEventQueue();
      tabA.log('a2');
      await tabA.flush();
      tabA.dispose();
      store.gate!.complete();
      await restoring;

      expect(online.sentNames, ['a1']);
      expect(_storedNames(store), ['a2']);

      store.gate = null;
      final next = _FakeGateway();
      final tabC = _logger(next, store, sessionId: _sessionC);
      await tabC.flush();
      expect(next.sentNames, ['a2']);
      expect(store.values, isEmpty);
    });

    test('두 탭이 서로의 행을 지우지 않고 남은 행은 다음 실행이 모두 보낸다', () async {
      final store = MemoryTelemetryQueueStore();
      final tabA = _logger(_offline(), store);
      tabA.log('a1');
      await tabA.flush();

      final tabB = _logger(_offline(), store, sessionId: _sessionB);
      tabB.log('b1');
      await tabB.flush();
      tabA.log('a2');
      await tabA.flush();
      expect(_storedNames(store), ['a1', 'b1', 'a2']);

      final online = _FakeGateway();
      final tabC = _logger(online, store, sessionId: _sessionC);
      await tabC.flush();
      expect(online.sentNames, ['a1', 'b1', 'a2']);
      expect(store.values, isEmpty);
    });
  });

  group('용량 상한', () {
    test('행 수와 바이트 예산을 넘으면 오래된 행부터 버린다', () async {
      final store = MemoryTelemetryQueueStore();
      final byRows = _logger(_offline(), store, maxQueue: 3);
      for (var i = 0; i < 5; i++) {
        byRows.log('e$i');
      }
      await byRows.flush();
      expect(_storedNames(store), ['e2', 'e3', 'e4']);

      final bytesStore = MemoryTelemetryQueueStore();
      final byBytes = _logger(
        _offline(),
        bytesStore,
        sessionId: _sessionB,
        maxQueueBytes: 1000,
      );
      for (var i = 0; i < 5; i++) {
        byBytes.log('e$i', {'pad': 'x' * 64, 'i': i});
      }
      await byBytes.flush();
      final kept = byBytes.pendingCount;
      expect(kept, inInclusiveRange(1, 4));
      expect(_storedNames(bytesStore), [
        for (var i = 5 - kept; i < 5; i++) 'e$i',
      ]);
      final bytes = bytesStore.values.values.fold<int>(
        0,
        (sum, v) =>
            sum + utf8.encode(jsonEncode((jsonDecode(v) as Map)['r'])).length,
      );
      expect(bytes, lessThanOrEqualTo(1000));
    });

    test('오래 켜 둔 앱에서도 7일이 지난 행은 전송 직전에 버린다', () async {
      final store = MemoryTelemetryQueueStore();
      final gateway = _offline();
      final logger = _logger(gateway, store);
      logger.log('stale');
      await logger.flush();
      _clock = _start.add(const Duration(days: 7, seconds: 1));
      gateway.respond = () async => const BackendResult.success(null);
      await logger.flush();
      expect(gateway.sent, isEmpty);
      expect(logger.pendingCount, 0);
      expect(store.values, isEmpty);
    });

    test('보관 기한을 넘긴 행은 복원하지 않고 지운다', () async {
      final store = MemoryTelemetryQueueStore();
      final old = _logger(_offline(), store);
      old.log('stale');
      _clock = _start.add(const Duration(days: 1));
      old.log('fresh');
      await old.flush();
      _clock = _start.add(const Duration(days: 7, seconds: 1));

      final gateway = _FakeGateway();
      final next = _logger(gateway, store, sessionId: _sessionB);
      await next.flush();
      expect(gateway.sentNames, ['fresh']);
      expect(store.values, isEmpty);
    });
  });

  test('운영 SharedPreferences 저장소는 접두어 키만 읽고 쓰고 지운다', () async {
    SharedPreferences.setMockInitialValues({'other': 'x', 'n': 1});
    const store = PrefsTelemetryQueueStore();
    await store.write('telemetry.queue.v2.a.s1', 'v1');
    expect(await store.readAll('telemetry.queue.v2.a.'), {
      'telemetry.queue.v2.a.s1': 'v1',
    });
    await store.remove('telemetry.queue.v2.a.s1');
    expect(await store.readAll('telemetry.queue.v2.'), isEmpty);
  });
}
