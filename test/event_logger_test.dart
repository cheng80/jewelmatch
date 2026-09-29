import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stonematch/services/backend/pocketbase_config.dart';
import 'package:stonematch/services/backend/pocketbase_gateway.dart';
import 'package:stonematch/services/event_logger.dart';
import 'package:stonematch/services/play_event_context.dart';
import 'package:stonematch/services/telemetry_policy.dart';

const _config = PocketBaseConfig(url: 'https://pb.example');
const _unconfigured = PocketBaseConfig(url: '');

final _start = DateTime.utc(2026, 9, 23, 12);
var _clock = _start;

/// 게스트 인증은 여기서 처리하고 이벤트 요청만 [handler]에 넘긴다.
PocketBaseGateway _gateway(
  Future<http.Response> Function(http.Request) handler, {
  String userId = 'user-1',
}) => PocketBaseGateway(
  config: _config,
  now: () => _clock,
  client: MockClient((request) async {
    if (request.url.path.endsWith('/auth/guest')) {
      return http.Response(
        jsonEncode({
          'token': 'token',
          'record': {'id': userId},
          'expires_in': 86400,
        }),
        200,
      );
    }
    return handler(request);
  }),
);

/// backoff가 끝난 시각으로 옮긴 뒤 다시 보낸다.
Future<void> _retry(EventLogger logger) {
  _clock = _clock.add(EventLogger.maxBackoff);
  return logger.flush();
}

const _testPolicy = TelemetryPolicy(env: TelemetryEnv.test);

EventLogger _logger(
  PocketBaseGateway gateway, {
  int batchSize = 20,
  TelemetryPolicy policy = _testPolicy,
}) => EventLogger(
  gateway: gateway,
  flushDelay: const Duration(hours: 1),
  batchSize: batchSize,
  maxQueue: 5,
  now: () => _clock,
  sessionId: '00000000-0000-4000-8000-000000000000',
  channel: 'intoss',
  policy: policy,
);

void main() {
  setUp(() => _clock = _start);

  test('백엔드 설정이 없으면 이벤트를 쌓지 않는다', () {
    final logger = EventLogger(
      gateway: PocketBaseGateway(config: _unconfigured),
    );
    addTearDown(logger.dispose);

    logger.log('round_start', {'mode': 'timed'});

    expect(logger.pendingCount, 0);
  });

  test('이름 규칙을 어긴 이벤트는 버리고 값은 허용 형식만 남긴다', () async {
    final bodies = <List<dynamic>>[];
    final logger = _logger(
      _gateway((request) async {
        bodies.add(jsonDecode(request.body) as List<dynamic>);
        return http.Response('', 204);
      }),
    );
    addTearDown(logger.dispose);
    logger.appVersion = '1.0.0+1';

    logger.log('Bad Name');
    logger.log('round_end', {
      'mode': 'timed',
      'score': 1200,
      'ok': true,
      'long': 'x' * 100,
      'nested': {'a': 1},
      'Bad Key': 1,
    });
    await logger.flush();

    expect(bodies, hasLength(1));
    final row = bodies.single.single as Map<String, dynamic>;
    expect(row['name'], 'round_end');
    expect(row['session_id'], '00000000-0000-4000-8000-000000000000');
    expect(row['channel'], 'intoss');
    expect(row['app_version'], '1.0.0+1');
    expect(row['client_ts'], '2026-09-23T12:00:00.000Z');
    final params = row['params'] as Map<String, dynamic>;
    expect(
      params.keys,
      unorderedEquals([
        'mode',
        'score',
        'ok',
        'long',
        'event_id',
        'event_seq',
        'schema_version',
        'telemetry_env',
        'collection',
        'sample_rate',
      ]),
    );
    expect((params['long'] as String).length, 64);
  });

  test('배치 크기가 차면 바로 보낸다', () async {
    var posts = 0;
    final logger = _logger(
      _gateway((_) async {
        posts += 1;
        return http.Response('', 204);
      }),
      batchSize: 2,
    );
    addTearDown(logger.dispose);

    logger.log('round_start');
    logger.log('round_start');
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(posts, 1);
    expect(logger.pendingCount, 0);
  });

  test('네트워크 실패는 큐에 되돌리고 거절된 데이터는 버린다', () async {
    var fail = true;
    final offline = _logger(
      _gateway((_) async {
        if (fail) throw Exception('offline');
        return http.Response('', 204);
      }),
    );
    addTearDown(offline.dispose);
    offline.log('session_start');
    await offline.flush();
    expect(offline.pendingCount, 1);
    fail = false;
    await _retry(offline);
    expect(offline.pendingCount, 0);

    final rejected = _logger(
      _gateway((_) async => http.Response(jsonEncode({'code': '23514'}), 400)),
    );
    addTearDown(rejected.dispose);
    rejected.log('session_start');
    await rejected.flush();
    expect(rejected.pendingCount, 0);

    final paths = <String>[];
    final forbidden = _logger(
      _gateway((request) async {
        paths.add(request.url.path);
        return http.Response(jsonEncode({'code': '42501'}), 403);
      }),
    );
    addTearDown(forbidden.dispose);
    forbidden.log('session_start');
    await forbidden.flush();
    expect(forbidden.pendingCount, 0);
    expect(paths, ['/api/stone-match/events']);
  });

  test('큐는 최대 개수를 넘으면 오래된 이벤트부터 버린다', () {
    final logger = _logger(_gateway((_) async => http.Response('', 204)));
    addTearDown(logger.dispose);

    for (var i = 0; i < 8; i++) {
      logger.log('round_start', {'i': i});
    }

    expect(logger.pendingCount, 5);
  });

  group('식별 메타데이터', () {
    final uuid = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );

    /// 실제 MockClient 요청 본문에서 params만 모은다.
    (EventLogger, List<Map<String, dynamic>>, void Function(bool)) setup({
      int batchSize = 20,
      TelemetryPolicy policy = _testPolicy,
    }) {
      final rows = <Map<String, dynamic>>[];
      var fail = false;
      final logger = _logger(
        _gateway((request) async {
          if (fail) throw Exception('offline');
          for (final row in jsonDecode(request.body) as List<dynamic>) {
            rows.add(row as Map<String, dynamic>);
          }
          return http.Response('', 204);
        }),
        batchSize: batchSize,
        policy: policy,
      );
      addTearDown(logger.dispose);
      return (logger, rows, (v) => fail = v);
    }

    Map<String, dynamic> p(Map<String, dynamic> row) =>
        row['params'] as Map<String, dynamic>;

    test('event_id는 UUID이고 서로 다르며 event_seq는 1부터 증가한다', () async {
      final (logger, rows, _) = setup();

      for (var i = 0; i < 5; i++) {
        logger.log('round_start', {'i': i});
      }
      await logger.flush();

      expect(rows, hasLength(5));
      final ids = rows.map((r) => p(r)['event_id'] as String).toList();
      expect(ids.every(uuid.hasMatch), isTrue);
      expect(ids.toSet(), hasLength(5));
      expect(rows.map((r) => p(r)['event_seq']), [1, 2, 3, 4, 5]);
      expect(rows.map((r) => p(r)['schema_version']), everyElement(3));
    });

    test('버려지는 이름의 이벤트는 순번을 쓰지 않는다', () async {
      final (logger, rows, _) = setup();

      logger.log('Bad Name');
      logger.log('round_start');
      await logger.flush();

      expect(p(rows.single)['event_seq'], 1);
    });

    test('재전송해도 event_id와 event_seq가 같다', () async {
      final (logger, rows, setFail) = setup();

      logger.log('round_start', {'score': 7});
      setFail(true);
      await logger.flush();
      expect(logger.pendingCount, 1);
      setFail(false);
      await _retry(logger);
      logger.log('round_end');
      await logger.flush();

      expect(rows, hasLength(2));
      expect(p(rows[0])['event_seq'], 1);
      expect(p(rows[1])['event_seq'], 2);
      expect(p(rows[0])['event_id'], isNot(p(rows[1])['event_id']));

      // 같은 행을 두 번 보내는 실패 시나리오에서 첫 시도와 재시도 본문이 같다.
      final bodies = <String>[];
      var attempt = 0;
      final retry = _logger(
        _gateway((request) async {
          bodies.add(request.body);
          if (attempt++ == 0) throw Exception('offline');
          return http.Response('', 204);
        }),
      );
      addTearDown(retry.dispose);
      retry.log('session_start', {'a': 1});
      await retry.flush();
      await _retry(retry);
      expect(bodies, hasLength(2));
      expect(bodies[0], bodies[1]);
    });

    test('호출자는 예약 필드를 덮어쓸 수 없고 한도를 쓰지도 않는다', () async {
      final (logger, rows, _) = setup();

      logger.log('round_end', {
        'event_id': 'spoof',
        'event_seq': 999,
        'schema_version': 99,
        'telemetry_env': 'production',
        'collection': 'sampled',
        'sample_rate': 0.5,
        'params_dropped': 5,
        for (var i = 0; i < 12; i++) 'k$i': i,
        'k12': 12,
      });
      await logger.flush();

      final params = p(rows.single);
      expect(uuid.hasMatch(params['event_id'] as String), isTrue);
      expect(params['event_seq'], 1);
      expect(params['schema_version'], 3);
      expect(params['telemetry_env'], 'test');
      expect(params['collection'], 'full');
      expect(params['sample_rate'], 1.0);
      expect(params.containsKey('params_dropped'), isFalse);
      final user = params.keys.where((k) => k.startsWith('k')).toList();
      expect(user, List.generate(12, (i) => 'k$i'));
    });

    test('비유한 숫자와 중첩값은 그 항목만 버리고 로깅은 계속된다', () async {
      final (logger, rows, _) = setup();

      logger.log('round_end', {
        'nan': double.nan,
        'inf': double.infinity,
        'ninf': double.negativeInfinity,
        'list': [1, 2],
        'obj': Object(),
        'nul': null,
        'neg': -0.0,
        'ok': 3,
      });
      await logger.flush();

      final params = p(rows.single);
      expect(params.keys.toSet(), {
        'event_id',
        'event_seq',
        'schema_version',
        'telemetry_env',
        'collection',
        'sample_rate',
        'neg',
        'ok',
      });
    });

    test('극단 유한 숫자는 값 그대로 보존한다', () async {
      final (logger, rows, _) = setup();
      final extremes = <String, num>{
        'huge': 1e308,
        'max_double': 1.7976931348623157e308,
        // JS 정수 정밀도 경계. 두 플랫폼 모두 정확한 정수다.
        'safe_int': 9007199254740991,
        'neg_safe_int': -9007199254740991,
        'tiny': 1e-308,
        'denorm': 5e-324,
        'neg_huge': -1e308,
        'neg_zero': -0.0,
        'zero': 0,
        'frac': 0.30000000000000004,
      };

      logger.log('round_end', extremes);
      await logger.flush();

      final params = p(rows.single);
      for (final entry in extremes.entries) {
        expect(params[entry.key], entry.value, reason: entry.key);
      }
    });

    // int64 경계는 컴파일 타임 리터럴로 쓰면 웹(JS) 컴파일이 거절한다. 문자열에서 만든다.
    // VM/Wasm은 정확한 int64, JS 숫자 의미(dart2js)는 int.parse가 만든 가장 가까운 double이다.
    // kIsWeb은 JS와 Wasm을 구분하지 않으므로 identical(1, 1.0)으로 JS 숫자 의미를 판별한다.
    test('int64 경계는 플랫폼의 정수 표현 그대로 보존한다', () async {
      final (logger, rows, _) = setup();
      final max = int.parse('9223372036854775807');
      final min = int.parse('-9223372036854775808');
      if (identical(1, 1.0)) {
        expect(max, 9223372036854775808.0);
        expect(min, -9223372036854775808.0);
      } else {
        expect(max.toString(), '9223372036854775807');
        expect(min.toString(), '-9223372036854775808');
        expect(max + 1, min); // VM int64 순환
      }

      logger.log('round_end', {'max_int': max, 'min_int': min});
      await logger.flush();

      final params = p(rows.single);
      expect(params['max_int'], max);
      expect(params['min_int'], min);
      expect(params['max_int'].toString(), max.toString());
    });

    test('극단 숫자, 긴 키, 긴 문자열이 섞인 12개도 1500바이트 이하로 남는다', () async {
      final (logger, rows, _) = setup();
      final longKey = 'k' * 40;

      logger.log('round_end', {
        for (var i = 0; i < 12; i++)
          '${longKey.substring(0, 38)}${i.toString().padLeft(2, '0')}':
              switch (i % 4) {
                0 => 1.7976931348623157e308,
                1 => -2.2250738585072014e-308,
                2 => 1.2345678901234567e11,
                _ => '\u{1F48E}' * 64,
              },
      });
      await logger.flush();

      final params = p(rows.single);
      expect(
        utf8.encode(jsonEncode(params)).length,
        lessThanOrEqualTo(EventLogger.maxParamsBytes),
      );
      expect(params['k' * 38 + '00'], 1.7976931348623157e308);
      expect(params['k' * 38 + '01'], -2.2250738585072014e-308);
      expect(params['event_seq'], 1);
    });

    test('문자열은 코드포인트 64개로 자르고 NUL과 짝 없는 surrogate를 정리한다', () async {
      final (logger, rows, _) = setup();
      final emoji = '\u{1F48E}' * 70; // UTF-16 140 유닛
      final lone = 'a\uD800b\uDC00c\u0000d';

      logger.log('round_end', {'emoji': emoji, 'lone': lone, 'han': '가' * 100});
      await logger.flush();

      final params = p(rows.single);
      expect((params['emoji'] as String).runes.length, 64);
      expect(params['emoji'], '\u{1F48E}' * 64);
      expect(params['lone'], 'a�b�cd');
      expect((params['han'] as String).length, 64);
    });

    test('params 크기 상한 경계: 상한 이내는 그대로, 초과는 뒤 항목부터 버리고 개수를 남긴다', () async {
      final (logger, rows, _) = setup();
      String pad(int n) => 'ㄱ' * n; // UTF-8 3바이트

      // 큰 문자열 4개(각 192바이트)는 들어가고 뒤 항목은 상한을 넘는다.
      logger.log('round_end', {
        for (var i = 0; i < 12; i++)
          'field_number_${i}_padding_key_name_x': pad(64),
      });
      logger.log('round_end', {'a': 1});
      await logger.flush();

      final big = p(rows[0]);
      final size = utf8.encode(jsonEncode(big)).length;
      expect(size, lessThanOrEqualTo(EventLogger.maxParamsBytes));
      final kept = big.keys.where((k) => k.startsWith('field_')).length;
      expect(kept, greaterThan(0));
      expect(kept, lessThan(12));
      expect(big['params_dropped'], 12 - kept);
      // 앞쪽 항목이 남는다.
      expect(big.containsKey('field_number_0_padding_key_name_x'), isTrue);
      expect(big.containsKey('field_number_11_padding_key_name_x'), isFalse);

      expect(p(rows[1]).containsKey('params_dropped'), isFalse);
    });

    test('상한 정확한 경계: 들어가면 남기고 1바이트라도 넘으면 버린다', () async {
      final (logger, rows, _) = setup();
      final key = 'k' * 40;
      final fixed = {
        for (var i = 0; i < 5; i++)
          '${key.substring(0, 39)}$i': '가' * 64, // 각 192바이트
      };
      final lastKey = '${key.substring(0, 38)}zz';
      final extras = List.generate(65, (m) => '가' * m);
      for (final extra in extras) {
        logger.log('round_end', {...fixed, lastKey: extra});
        await logger.flush();
      }

      var sawKept = false, sawDropped = false;
      for (var m = 0; m < extras.length; m++) {
        final params = p(rows[m]);
        expect(
          utf8.encode(jsonEncode(params)).length,
          lessThanOrEqualTo(EventLogger.maxParamsBytes),
        );
        final withLast = {...params, lastKey: extras[m]}
          ..remove('params_dropped');
        final fits =
            utf8.encode(jsonEncode(withLast)).length <=
            EventLogger.maxParamsBytes;
        expect(params.containsKey(lastKey), fits, reason: 'm=$m');
        expect(params.containsKey('params_dropped'), !fits, reason: 'm=$m');
        sawKept |= fits;
        sawDropped |= !fits;
      }
      expect(sawKept && sawDropped, isTrue);
    });

    test('최악 입력 12개도 UTF-8 JSON 1500바이트 이하이고 DB 2048 여유가 있다', () async {
      final (logger, rows, _) = setup();
      final key = 'k' * 40;

      logger.log('round_end', {
        for (var i = 0; i < 12; i++)
          '${key.substring(0, 38)}${i.toString().padLeft(2, '0')}':
              '\u{1F48E}' * 64,
      });
      await logger.flush();

      final params = p(rows.single);
      expect(
        utf8.encode(jsonEncode(params)).length,
        lessThanOrEqualTo(EventLogger.maxParamsBytes),
      );
      expect(params['event_seq'], 1);
      expect(params['params_dropped'], greaterThan(0));
    });

    group('플레이 문맥', () {
      const contextKeys = ['run_id', 'round_seq', 'attempt_seq'];

      test('문맥 없는 log는 문맥 필드를 붙이지 않고 호출자 값도 지운다', () async {
        final (logger, rows, _) = setup();

        logger.log('round_start', {
          'run_id': 'forged',
          'round_seq': 9,
          'attempt_seq': 9,
          'a': 1,
        });
        await logger.flush();

        final params = p(rows.single);
        expect(
          params.keys,
          unorderedEquals([
            'a',
            'event_id',
            'event_seq',
            'schema_version',
            'telemetry_env',
            'collection',
            'sample_rate',
          ]),
        );
        expect(params['schema_version'], 3);
      });

      test('logPlay는 문맥을 붙이고 호출자의 예약 필드 덮어쓰기를 막는다', () async {
        final (logger, rows, _) = setup();
        final ctx = PlayEventContext.startRun().nextRound().nextAttempt();

        logger.logPlay('round_end', ctx, {
          'run_id': 'forged',
          'round_seq': 99,
          'attempt_seq': 99,
          'event_id': 'forged',
          'event_seq': 99,
          'schema_version': 99,
          'telemetry_env': 'production',
          'collection': 'sampled',
          'sample_rate': 0.5,
          'params_dropped': 99,
          'score': 10,
        });
        await logger.flush();

        final params = p(rows.single);
        expect(params['run_id'], ctx.runId);
        expect(params['round_seq'], 2);
        expect(params['attempt_seq'], 1);
        expect(params['score'], 10);
        expect(uuid.hasMatch(params['event_id'] as String), isTrue);
        expect(params['event_seq'], 1);
        expect(params['schema_version'], 3);
        expect(params['telemetry_env'], 'test');
        expect(params['collection'], 'full');
        expect(params['sample_rate'], 1.0);
        expect(params.containsKey('params_dropped'), isFalse);
      });

      test('문맥 필드는 사용자 파라미터 12개 한도에 세지 않는다', () async {
        final (logger, rows, _) = setup();
        final ctx = PlayEventContext.startRun();

        logger.logPlay('round_end', ctx, {
          for (var i = 0; i < 14; i++) 'k$i': i,
        });
        await logger.flush();

        final params = p(rows.single);
        expect(params.keys.where((k) => k.startsWith('k')), hasLength(12));
        expect(contextKeys.every(params.containsKey), isTrue);
      });

      test('재전송 본문은 같고 이후 문맥이 바뀌어도 큐의 행은 스냅샷이다', () async {
        final bodies = <String>[];
        var attempt = 0;
        final logger = _logger(
          _gateway((request) async {
            bodies.add(request.body);
            if (attempt++ == 0) throw Exception('offline');
            return http.Response('', 204);
          }),
        );
        addTearDown(logger.dispose);
        final first = PlayEventContext.startRun();

        logger.logPlay('round_end', first, {'score': 1});
        final advanced = first.nextAttempt(); // 이후 진행해도 큐의 행은 그대로.
        logger.logPlay('round_start', advanced);
        await logger.flush();
        await _retry(logger);

        expect(bodies, hasLength(2));
        expect(bodies[0], bodies[1]);
        final rows = jsonDecode(bodies[1]) as List<dynamic>;
        final p0 = (rows[0] as Map)['params'] as Map;
        final p1 = (rows[1] as Map)['params'] as Map;
        expect(p0['attempt_seq'], 0);
        expect(p1['attempt_seq'], 1);
        expect(p0['run_id'], p1['run_id']);
      });

      test('run, round, attempt 조합은 겹치지 않고 event_id도 다르다', () async {
        final (logger, rows, _) = setup(batchSize: 100);
        final run1 = PlayEventContext.startRun();
        final run2 = PlayEventContext.startRun();
        final contexts = [
          run1,
          run1.nextAttempt(),
          run1.nextAttempt().nextAttempt(),
          run1.nextRound(),
          run1.nextRound().nextAttempt(),
          run1.nextRound().nextRound(),
          run2,
          run2.nextRound(),
        ];
        for (final c in contexts) {
          logger.logPlay('round_end', c);
          await logger.flush(); // 테스트 큐 상한(5)보다 많아 하나씩 보낸다.
        }

        final keys = rows
            .map((r) => contextKeys.map((k) => p(r)[k]).join('/'))
            .toSet();
        expect(keys, hasLength(contexts.length));
        expect(
          rows.map((r) => p(r)['event_id']).toSet(),
          hasLength(contexts.length),
        );
        expect(run1.runId, isNot(run2.runId));
      });

      test('사용자 12개 최악 입력과 큰 문맥 값도 1500바이트 이하다', () async {
        final (logger, rows, _) = setup();
        final key = 'k' * 40;
        final ctx = PlayEventContext(
          runId: PlayEventContext.startRun().runId,
          roundSeq: 999999999,
          attemptSeq: 999999999,
        );

        logger.logPlay('round_end', ctx, {
          for (var i = 0; i < 12; i++)
            '${key.substring(0, 38)}${i.toString().padLeft(2, '0')}':
                '\u{1F48E}' * 64,
        });
        await logger.flush();

        final params = p(rows.single);
        expect(
          utf8.encode(jsonEncode(params)).length,
          lessThanOrEqualTo(EventLogger.maxParamsBytes),
        );
        expect(params['run_id'], ctx.runId);
        expect(params['round_seq'], 999999999);
        expect(params['attempt_seq'], 999999999);
        expect(params['params_dropped'], greaterThan(0));
      });
    });

    group('logBehavior 표본 정책', () {
      const sampled = TelemetryPolicy(
        env: TelemetryEnv.production,
        sessionSampled: true,
        maxSampledEvents: 3,
      );

      test('표본 세션은 sampled와 표본 비율을 붙이고 log는 full 1.0이다', () async {
        final (logger, rows, _) = setup(policy: sampled);
        final ctx = PlayEventContext.startRun();

        logger.logBehavior('menu_open', {'a': 1}, context: ctx);
        logger.log('round_start');
        await logger.flush();

        final behavior = p(rows[0]);
        expect(behavior['collection'], 'sampled');
        expect(behavior['sample_rate'], 0.1);
        expect(behavior['telemetry_env'], 'production');
        expect(behavior['schema_version'], 3);
        expect(behavior['run_id'], ctx.runId);
        expect(behavior['a'], 1);
        final full = p(rows[1]);
        expect(full['collection'], 'full');
        expect(full['sample_rate'], 1.0);
        expect(full['telemetry_env'], 'production');
      });

      test('표본이 아닌 세션은 행동 이벤트를 버리지만 log와 logPlay는 100% 남긴다', () async {
        final (logger, rows, _) = setup(
          policy: const TelemetryPolicy(sessionSampled: false),
        );
        final ctx = PlayEventContext.startRun();

        logger.logBehavior('menu_open', {'a': 1});
        expect(logger.pendingCount, 0);
        for (var i = 0; i < 4; i++) {
          logger.log('e$i');
        }
        logger.logPlay('round_end', ctx);
        logger.logBehavior('menu_open', {'a': 1});
        await logger.flush();

        expect(rows, hasLength(5)); // 테스트 큐 한도 5건 안에서 전부 남는다
        expect(rows.every((r) => p(r)['collection'] == 'full'), isTrue);
        expect(p(rows.last)['event_seq'], 5);
      });

      test('세션당 상한을 넘긴 행동 이벤트만 버리고 full 이벤트는 계속 남긴다', () async {
        final (logger, rows, _) = setup(policy: sampled);

        for (var i = 0; i < 10; i++) {
          logger.logBehavior('menu_open', {'i': i});
        }
        logger.log('round_end');
        logger.logBehavior('menu_open', {'i': 99});
        await logger.flush();

        final behavior = rows.where((r) => p(r)['collection'] == 'sampled');
        expect(behavior.map((r) => p(r)['i']), [0, 1, 2]);
        expect(rows, hasLength(4));
        expect(p(rows.last)['event_seq'], 4); // 버린 이벤트는 event_seq를 쓰지 않는다
      });

      test('잘못된 이름은 상한을 쓰지 않는다', () async {
        final (logger, rows, _) = setup(policy: sampled);

        for (var i = 0; i < 5; i++) {
          logger.logBehavior('Bad Name', {});
        }
        for (var i = 0; i < 3; i++) {
          logger.logBehavior('ok_name', {});
        }
        await logger.flush();

        expect(rows, hasLength(3));
      });

      test('백엔드 미설정이면 상한도 쓰지 않는다', () {
        final logger = EventLogger(
          gateway: PocketBaseGateway(config: _unconfigured),
          policy: sampled,
        );
        addTearDown(logger.dispose);

        logger.logBehavior('menu_open', {});

        expect(logger.pendingCount, 0);
      });

      test('호출자는 telemetry 예약 필드를 덮어쓸 수 없다', () async {
        final (logger, rows, _) = setup(policy: sampled);

        logger.logBehavior('menu_open', {
          'telemetry_env': 'production',
          'collection': 'full',
          'sample_rate': 1.0,
          'schema_version': 2,
        });
        await logger.flush();

        final params = p(rows.single);
        expect(params['collection'], 'sampled');
        expect(params['sample_rate'], 0.1);
        expect(params['schema_version'], 3);
      });

      test('표본 선택은 세션 ID로 고정되고 매 이벤트 난수가 아니다', () {
        const policy = TelemetryPolicy();
        final logger = _logger(
          _gateway((_) async => http.Response('', 204)),
          policy: policy,
        );
        addTearDown(logger.dispose);

        expect(
          logger.sessionSampled,
          policy.isSessionSampled(logger.sessionId),
        );
        expect(logger.sessionSampled, logger.sessionSampled);
      });

      test('실패한 전송은 같은 행을 다시 보내 메타데이터가 유지된다', () async {
        final bodies = <String>[];
        var attempt = 0;
        final logger = _logger(
          _gateway((request) async {
            bodies.add(request.body);
            if (attempt++ == 0) throw Exception('offline');
            return http.Response('', 204);
          }),
          policy: sampled,
        );
        addTearDown(logger.dispose);

        logger.logBehavior('menu_open', {'a': 1});
        await logger.flush();
        await _retry(logger);

        expect(bodies, hasLength(2));
        expect(bodies[1], bodies[0]);
        final params = (jsonDecode(bodies[1]) as List).single['params'] as Map;
        expect(params['collection'], 'sampled');
        expect(params['sample_rate'], 0.1);
      });

      test('큰 파라미터에서도 예약 메타데이터가 1500바이트 안에 들어간다', () async {
        final (logger, rows, _) = setup(policy: sampled);
        final ctx = PlayEventContext.startRun().nextRound().nextAttempt();

        logger.logBehavior('menu_open', {
          for (var i = 0; i < 12; i++) 'key_$i': '\u{1F48E}' * 64,
        }, context: ctx);
        await logger.flush();

        final params = p(rows.single);
        expect(
          utf8.encode(jsonEncode(params)).length,
          lessThanOrEqualTo(EventLogger.maxParamsBytes),
        );
        expect(params['telemetry_env'], 'production');
        expect(params['collection'], 'sampled');
        expect(params['sample_rate'], 0.1);
        expect(params['run_id'], ctx.runId);
        expect(params['params_dropped'], greaterThan(0));
      });
    });

    group('늦게 켜지는 QA 스위치', () {
      test('QA 라우트가 로거 생성 뒤에 켜지면 다음 이벤트부터 qa이고 세션 끝까지 유지한다', () async {
        var url = Uri.parse('https://x.test/#/');
        final policy = TelemetryPolicy(
          env: TelemetryEnv.production,
          sessionSampled: true,
          qaProbe: () => TelemetryPolicy.isQaActive(uri: url, defines: false),
        );
        final (logger, rows, _) = setup(policy: policy);

        logger.log('title_view');
        url = Uri.parse('https://x.test/#/game?qaNoMoves=1');
        logger.log('round_start');
        logger.logBehavior('menu_open', {});
        url = Uri.parse('https://x.test/#/'); // QA 라우트에서 나가도
        logger.log('title_view');
        await logger.flush();

        expect(rows.map((r) => p(r)['telemetry_env']), [
          'production',
          'qa',
          'qa',
          'qa',
        ]);
        expect(logger.telemetryEnv, TelemetryEnv.qa);
      });

      test('이미 쌓인 행은 QA가 켜져도 만들 때의 환경으로 재전송된다', () async {
        var qaOn = false;
        final bodies = <String>[];
        var attempt = 0;
        final logger = _logger(
          _gateway((request) async {
            bodies.add(request.body);
            if (attempt++ == 0) throw Exception('offline');
            return http.Response('', 204);
          }),
          policy: TelemetryPolicy(
            env: TelemetryEnv.production,
            qaProbe: () => qaOn,
          ),
        );
        addTearDown(logger.dispose);

        logger.log('round_start');
        await logger.flush(); // 실패, 큐에 되돌림
        qaOn = true;
        await _retry(logger);

        expect(bodies, hasLength(2));
        expect(bodies[1], bodies[0]);
        final params = (jsonDecode(bodies[1]) as List).single['params'] as Map;
        expect(params['telemetry_env'], 'production');
        logger.log('round_end');
        expect(logger.telemetryEnv, TelemetryEnv.qa);
      });

      test('probe가 없으면 QA를 감지하지 않아 test 격리가 유지된다', () async {
        final (logger, rows, _) = setup();

        logger.log('round_start');
        await logger.flush();

        expect(p(rows.single)['telemetry_env'], 'test');
      });

      test('probe가 예외를 던져도 로깅은 계속된다', () async {
        final (logger, rows, _) = setup(
          policy: TelemetryPolicy(
            env: TelemetryEnv.production,
            qaProbe: () => throw StateError('boom'),
          ),
        );

        logger.log('round_start');
        await logger.flush();

        expect(p(rows.single)['telemetry_env'], 'production');
      });
    });

    test('메타데이터 생성이 실패해도 log는 예외를 던지지 않는다', () {
      final logger = EventLogger(
        gateway: _gateway((_) async => http.Response('', 204)),
        now: () => throw StateError('clock'),
      );
      addTearDown(logger.dispose);

      expect(() => logger.log('round_start', {'a': 1}), returnsNormally);
      expect(logger.pendingCount, 0);
    });
  });
}
