import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stonematch/services/backend/supabase_config.dart';
import 'package:stonematch/services/backend/supabase_gateway.dart';
import 'package:stonematch/services/event_logger.dart';

const _config = SupabaseConfig(
  url: 'https://example.supabase.co',
  publishableKey: 'sb_publishable_test',
);

final _now = DateTime.utc(2026, 9, 23, 12);

SupabaseGateway _gateway(Future<http.Response> Function(http.Request) handler) {
  return SupabaseGateway(
    config: _config,
    now: () => _now,
    client: MockClient(handler),
    sessionStore: MemorySupabaseSessionStore(
      SupabaseSession(
        accessToken: 'token',
        refreshToken: 'refresh',
        expiresAt: _now.add(const Duration(hours: 1)),
        userId: 'user-1',
      ),
    ),
  );
}

EventLogger _logger(SupabaseGateway gateway, {int batchSize = 20}) =>
    EventLogger(
      gateway: gateway,
      flushDelay: const Duration(hours: 1),
      batchSize: batchSize,
      maxQueue: 5,
      now: () => _now,
      sessionId: '00000000-0000-4000-8000-000000000000',
      channel: 'intoss',
    );

void main() {
  test('Supabase 설정이 없으면 이벤트를 쌓지 않는다', () {
    final logger = EventLogger(
      gateway: SupabaseGateway(
        config: const SupabaseConfig(url: '', publishableKey: ''),
      ),
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
        return http.Response('', 201);
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
    expect(params.keys, unorderedEquals(['mode', 'score', 'ok', 'long']));
    expect((params['long'] as String).length, 64);
  });

  test('배치 크기가 차면 바로 보낸다', () async {
    var posts = 0;
    final logger = _logger(
      _gateway((_) async {
        posts += 1;
        return http.Response('', 201);
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
        return http.Response('', 201);
      }),
    );
    addTearDown(offline.dispose);
    offline.log('session_start');
    await offline.flush();
    expect(offline.pendingCount, 1);
    fail = false;
    await offline.flush();
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
    expect(paths, ['/rest/v1/game_events']);
  });

  test('큐는 최대 개수를 넘으면 오래된 이벤트부터 버린다', () {
    final logger = _logger(_gateway((_) async => http.Response('', 201)));
    addTearDown(logger.dispose);

    for (var i = 0; i < 8; i++) {
      logger.log('round_start', {'i': i});
    }

    expect(logger.pendingCount, 5);
  });
}
