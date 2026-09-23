import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stonematch/services/backend/supabase_config.dart';
import 'package:stonematch/services/backend/supabase_gateway.dart';

const testConfig = SupabaseConfig(
  url: 'https://example.supabase.co',
  publishableKey: 'sb_publishable_test',
);

http.Response jsonResponse(int status, Object? body) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, Object?> authBody({
  String access = 'token-1',
  String refresh = 'refresh-1',
  String userId = 'user-1',
}) => {
  'access_token': access,
  'refresh_token': refresh,
  'expires_in': 3600,
  'user': {'id': userId},
};

final fixedNow = DateTime.utc(2026, 9, 23, 12);

SupabaseSession sessionExpiringAt(DateTime expiresAt) => SupabaseSession(
  accessToken: 'old-token',
  refreshToken: 'old-refresh',
  expiresAt: expiresAt,
  userId: 'user-1',
);

/// 웹 저장소 흉내. 탭마다 캐시를 따로 두고 저장 매체(localStorage)만 공유한다.
/// read()는 캐시만 보므로 다른 탭이 쓴 값은 readLatest() 뒤에야 보인다.
class TabSessionStore implements SupabaseSessionStore {
  TabSessionStore(this.medium) : _cache = medium['session'];

  final Map<String, SupabaseSession?> medium;
  SupabaseSession? _cache;

  @override
  SupabaseSession? read() => _cache;

  @override
  Future<SupabaseSession?> readLatest() async => _cache = medium['session'];

  @override
  Future<void> write(SupabaseSession? session) async {
    _cache = session;
    medium['session'] = session;
  }
}

void main() {
  test('설정이 없으면 네트워크 없이 notConfigured를 돌려준다', () async {
    var called = false;
    final gateway = SupabaseGateway(
      config: const SupabaseConfig(url: 'http://insecure', publishableKey: 'k'),
      client: MockClient((_) async {
        called = true;
        return jsonResponse(200, {});
      }),
    );

    final result = await gateway.rpc('get_ranking', const {});

    expect(gateway.isConfigured, isFalse);
    expect(result.failure, BackendFailure.notConfigured);
    expect(called, isFalse);
  });

  test('첫 인증 호출에서 익명 가입하고 세션을 저장해 재사용한다', () async {
    final store = MemorySupabaseSessionStore();
    var signups = 0;
    final gateway = SupabaseGateway(
      config: testConfig,
      sessionStore: store,
      now: () => fixedNow,
      client: MockClient((request) async {
        if (request.url.path == '/auth/v1/signup') {
          signups += 1;
          expect(request.headers['apikey'], 'sb_publishable_test');
          return jsonResponse(200, authBody());
        }
        return jsonResponse(200, {'ok': true});
      }),
    );

    await gateway.rpc('ad_refill_status', const {});
    await gateway.rpc('ad_refill_status', const {});

    expect(signups, 1);
    expect(store.read()!.userId, 'user-1');
    expect(gateway.currentUserId, 'user-1');
  });

  test('동시에 호출해도 익명 가입은 한 번만 한다', () async {
    var signups = 0;
    final gateway = SupabaseGateway(
      config: testConfig,
      now: () => fixedNow,
      client: MockClient((request) async {
        if (request.url.path == '/auth/v1/signup') {
          signups += 1;
          await Future<void>.delayed(const Duration(milliseconds: 5));
          return jsonResponse(200, authBody());
        }
        return jsonResponse(200, {});
      }),
    );

    await Future.wait([
      gateway.rpc('a', const {}),
      gateway.rpc('b', const {}),
      gateway.ensureSession(),
    ]);

    expect(signups, 1);
  });

  test('만료 임박 세션은 refresh 토큰으로 갱신한다', () async {
    final store = MemorySupabaseSessionStore(
      sessionExpiringAt(fixedNow.add(const Duration(seconds: 30))),
    );
    final paths = <String>[];
    final gateway = SupabaseGateway(
      config: testConfig,
      sessionStore: store,
      now: () => fixedNow,
      client: MockClient((request) async {
        paths.add(request.url.toString());
        if (request.url.path == '/auth/v1/token') {
          expect(request.url.queryParameters['grant_type'], 'refresh_token');
          expect(jsonDecode(request.body), {'refresh_token': 'old-refresh'});
          return jsonResponse(200, authBody(access: 'new-token'));
        }
        expect(request.headers['Authorization'], 'Bearer new-token');
        return jsonResponse(200, {});
      }),
    );

    final result = await gateway.rpc('ad_refill_status', const {});

    expect(result.isSuccess, isTrue);
    expect(paths.first, contains('/auth/v1/token?grant_type=refresh_token'));
    expect(store.read()!.accessToken, 'new-token');
  });

  test('갱신이 네트워크 문제로 실패하면 새 익명 사용자를 만들지 않는다', () async {
    var signups = 0;
    final gateway = SupabaseGateway(
      config: testConfig,
      sessionStore: MemorySupabaseSessionStore(
        sessionExpiringAt(fixedNow.subtract(const Duration(minutes: 5))),
      ),
      now: () => fixedNow,
      client: MockClient((request) async {
        if (request.url.path == '/auth/v1/signup') signups += 1;
        throw Exception('offline');
      }),
    );

    final result = await gateway.ensureSession();

    expect(result.failure, BackendFailure.network);
    expect(signups, 0);
  });

  test('refresh 토큰이 거절되면 새로 익명 가입한다', () async {
    final gateway = SupabaseGateway(
      config: testConfig,
      sessionStore: MemorySupabaseSessionStore(
        sessionExpiringAt(fixedNow.subtract(const Duration(minutes: 5))),
      ),
      now: () => fixedNow,
      client: MockClient((request) async {
        if (request.url.path == '/auth/v1/token') {
          return jsonResponse(400, {'error_code': 'refresh_token_not_found'});
        }
        return jsonResponse(200, authBody(userId: 'user-2'));
      }),
    );

    final result = await gateway.ensureSession();

    expect(result.data!.userId, 'user-2');
  });

  test('서버가 토큰을 거절하면 한 번만 갱신 후 다시 보낸다', () async {
    var rpcCalls = 0;
    final gateway = SupabaseGateway(
      config: testConfig,
      sessionStore: MemorySupabaseSessionStore(
        sessionExpiringAt(fixedNow.add(const Duration(hours: 1))),
      ),
      now: () => fixedNow,
      client: MockClient((request) async {
        if (request.url.path == '/auth/v1/token') {
          return jsonResponse(200, authBody(access: 'fresh-token'));
        }
        rpcCalls += 1;
        if (request.headers['Authorization'] == 'Bearer old-token') {
          return jsonResponse(401, {'message': 'JWT expired'});
        }
        return jsonResponse(200, {'ok': true});
      }),
    );

    final result = await gateway.rpc('claim_ad_refill', const {'p_item': 'x'});

    expect(result.isSuccess, isTrue);
    expect(rpcCalls, 2);
  });

  test('오류 응답을 유형별로 분류한다', () async {
    Future<BackendFailure?> failureFor(int status, Object body) async {
      final gateway = SupabaseGateway(
        config: testConfig,
        client: MockClient((_) async => jsonResponse(status, body)),
      );
      return (await gateway.rpc('f', const {}, requireAuth: false)).failure;
    }

    expect(await failureFor(404, {}), BackendFailure.notFound);
    expect(await failureFor(429, {}), BackendFailure.rateLimited);
    expect(
      await failureFor(400, {
        'code': 'P0001',
        'message': 'game_events_rate_limited',
      }),
      BackendFailure.rateLimited,
    );
    expect(await failureFor(400, {'code': '23514'}), BackendFailure.rejected);
    expect(await failureFor(403, {}), BackendFailure.rejected);
    expect(await failureFor(503, {}), BackendFailure.server);
  });

  test('insert는 행 목록을 return=minimal로 보낸다', () async {
    late http.Request captured;
    final gateway = SupabaseGateway(
      config: testConfig,
      sessionStore: MemorySupabaseSessionStore(
        sessionExpiringAt(fixedNow.add(const Duration(hours: 1))),
      ),
      now: () => fixedNow,
      client: MockClient((request) async {
        captured = request;
        return http.Response('', 201);
      }),
    );

    final result = await gateway.insert('game_events', [
      {'name': 'a'},
      {'name': 'b'},
    ]);

    expect(result.isSuccess, isTrue);
    expect(captured.url.path, '/rest/v1/game_events');
    expect(captured.headers['Prefer'], 'return=minimal');
    expect(captured.headers['Authorization'], 'Bearer old-token');
    expect(jsonDecode(captured.body), hasLength(2));
  });

  test('403은 토큰을 갱신하지 않고 rejected로 돌려준다', () async {
    final paths = <String>[];
    final gateway = SupabaseGateway(
      config: testConfig,
      sessionStore: MemorySupabaseSessionStore(
        sessionExpiringAt(fixedNow.add(const Duration(hours: 1))),
      ),
      now: () => fixedNow,
      client: MockClient((request) async {
        paths.add(request.url.path);
        return jsonResponse(403, {'code': '42501'});
      }),
    );

    final result = await gateway.insert('game_events', [
      {'name': 'a'},
    ]);

    expect(result.failure, BackendFailure.rejected);
    expect(paths, ['/rest/v1/game_events']);
  });

  test('캐시가 따로인 다른 탭이 회전한 세션을 가입 없이 채택한다', () async {
    var now = fixedNow;
    final medium = <String, SupabaseSession?>{
      'session': sessionExpiringAt(fixedNow.add(const Duration(minutes: 5))),
    };
    final authPaths = <String>[];
    var refreshes = 0;
    http.Client client() => MockClient((request) async {
      if (request.url.path.startsWith('/auth/')) {
        authPaths.add(request.url.path);
        if (request.url.path == '/auth/v1/token') {
          refreshes += 1;
          if (jsonDecode(request.body)['refresh_token'] != 'old-refresh') {
            return jsonResponse(400, {'error_code': 'refresh_token_not_found'});
          }
          return jsonResponse(
            200,
            authBody(access: 'rotated-token', refresh: 'refresh-2'),
          );
        }
        return jsonResponse(200, authBody(userId: 'user-new'));
      }
      return jsonResponse(200, {});
    });
    final tabA = SupabaseGateway(
      config: testConfig,
      sessionStore: TabSessionStore(medium),
      now: () => now,
      client: client(),
    );
    final tabBStore = TabSessionStore(medium);
    final tabB = SupabaseGateway(
      config: testConfig,
      sessionStore: tabBStore,
      now: () => now,
      client: client(),
    );
    await tabA.ensureSession();
    await tabB.ensureSession();

    now = fixedNow.add(const Duration(minutes: 10));
    await tabA.ensureSession();
    // 탭 B의 캐시는 아직 옛 세션이다.
    expect(tabBStore.read()!.refreshToken, 'old-refresh');
    final result = await tabB.ensureSession();

    expect(refreshes, 1);
    expect(authPaths, isNot(contains('/auth/v1/signup')));
    expect(result.data!.refreshToken, 'refresh-2');
    expect(tabB.currentUserId, 'user-1');
  });

  test('다른 탭이 저장한 세션이 만료됐으면 그 refresh 토큰으로 갱신한다', () async {
    final medium = <String, SupabaseSession?>{
      'session': sessionExpiringAt(fixedNow.subtract(const Duration(hours: 2))),
    };
    final tabB = SupabaseGateway(
      config: testConfig,
      sessionStore: TabSessionStore(medium),
      now: () => fixedNow,
      client: MockClient((request) async {
        if (request.url.path == '/auth/v1/token' &&
            jsonDecode(request.body)['refresh_token'] == 'refresh-2') {
          return jsonResponse(200, authBody(refresh: 'refresh-3'));
        }
        return jsonResponse(400, {'error_code': 'refresh_token_already_used'});
      }),
    );
    // 탭 A가 R1을 R2로 회전한 뒤 닫혔고, 그 세션도 한참 전에 만료됐다.
    await TabSessionStore(medium).write(
      SupabaseSession(
        accessToken: 'other-tab-token',
        refreshToken: 'refresh-2',
        expiresAt: fixedNow.subtract(const Duration(hours: 1)),
        userId: 'user-1',
      ),
    );

    final result = await tabB.ensureSession();

    expect(result.data!.refreshToken, 'refresh-3');
    expect(result.data!.userId, 'user-1');
  });

  test('refresh 거절 뒤 가입 전에 저장소의 새 세션을 확인한다', () async {
    final medium = <String, SupabaseSession?>{
      'session': sessionExpiringAt(
        fixedNow.subtract(const Duration(minutes: 5)),
      ),
    };
    final otherTab = TabSessionStore(medium);
    var signups = 0;
    final gateway = SupabaseGateway(
      config: testConfig,
      sessionStore: TabSessionStore(medium),
      now: () => fixedNow,
      client: MockClient((request) async {
        if (request.url.path == '/auth/v1/signup') signups += 1;
        // 갱신 요청이 가는 동안 다른 탭이 회전을 끝내고 저장했다.
        await otherTab.write(
          SupabaseSession(
            accessToken: 'other-tab-token',
            refreshToken: 'refresh-2',
            expiresAt: fixedNow.add(const Duration(hours: 1)),
            userId: 'user-1',
          ),
        );
        return jsonResponse(400, {'error_code': 'refresh_token_already_used'});
      }),
    );

    final result = await gateway.ensureSession();

    expect(signups, 0);
    expect(result.data!.accessToken, 'other-tab-token');
  });

  test('인증 실패 뒤 대기 시간 동안 요청 없이 실패하고 대기는 2배로 늘어난다', () async {
    var now = fixedNow;
    var signups = 0;
    var failSignup = true;
    final gateway = SupabaseGateway(
      config: testConfig,
      now: () => now,
      client: MockClient((request) async {
        if (request.url.path == '/auth/v1/signup') {
          signups += 1;
          return failSignup
              ? jsonResponse(422, {'error_code': 'anonymous_provider_disabled'})
              : jsonResponse(200, authBody());
        }
        return jsonResponse(200, {});
      }),
    );

    expect((await gateway.ensureSession()).failure, BackendFailure.rejected);
    now = fixedNow.add(const Duration(seconds: 59));
    expect((await gateway.rpc('f', const {})).failure, BackendFailure.rejected);
    expect(signups, 1);

    now = fixedNow.add(const Duration(seconds: 60));
    await gateway.ensureSession();
    expect(signups, 2);
    // 두 번째 실패 뒤에는 120초를 기다린다.
    now = now.add(const Duration(seconds: 119));
    await gateway.ensureSession();
    expect(signups, 2);

    failSignup = false;
    now = now.add(const Duration(seconds: 1));
    expect((await gateway.ensureSession()).isSuccess, isTrue);
    expect(signups, 3);
  });

  test('네트워크 실패 뒤에는 10초만 쉬고 다시 시도한다', () async {
    var now = fixedNow;
    var refreshes = 0;
    var offline = true;
    final gateway = SupabaseGateway(
      config: testConfig,
      sessionStore: MemorySupabaseSessionStore(
        sessionExpiringAt(fixedNow.subtract(const Duration(minutes: 5))),
      ),
      now: () => now,
      client: MockClient((request) async {
        if (request.url.path == '/auth/v1/token') refreshes += 1;
        if (offline) throw Exception('offline');
        return jsonResponse(200, authBody());
      }),
    );

    for (var i = 0; i < 4; i++) {
      await gateway.ensureSession();
      now = now.add(const Duration(seconds: 10));
    }
    expect(refreshes, 4);

    offline = false;
    expect((await gateway.ensureSession()).isSuccess, isTrue);
  });

  test('시계를 되돌려 대기 끝이 10분보다 멀어지면 대기를 끝낸다', () async {
    var now = fixedNow;
    var signups = 0;
    final gateway = SupabaseGateway(
      config: testConfig,
      now: () => now,
      client: MockClient((request) async {
        signups += 1;
        return jsonResponse(422, {'error_code': 'anonymous_provider_disabled'});
      }),
    );

    await gateway.ensureSession();
    now = fixedNow.subtract(const Duration(days: 1));
    await gateway.ensureSession();

    expect(signups, 2);
  });

  test('갱신한 토큰도 401이면 대기 동안 갱신을 반복하지 않는다', () async {
    var now = fixedNow;
    var refreshes = 0;
    var inserts = 0;
    final gateway = SupabaseGateway(
      config: testConfig,
      sessionStore: MemorySupabaseSessionStore(
        sessionExpiringAt(fixedNow.add(const Duration(hours: 1))),
      ),
      now: () => now,
      client: MockClient((request) async {
        if (request.url.path == '/auth/v1/token') {
          refreshes += 1;
          return jsonResponse(200, authBody(refresh: 'refresh-$refreshes'));
        }
        inserts += 1;
        return jsonResponse(401, {'message': 'invalid JWT'});
      }),
    );
    Future<BackendFailure?> insert() async =>
        (await gateway.insert('game_events', [
          {'name': 'a'},
        ])).failure;

    expect(await insert(), BackendFailure.unauthorized);
    expect(refreshes, 1);
    expect(inserts, 2);

    now = now.add(const Duration(seconds: 30));
    expect(await insert(), BackendFailure.unauthorized);
    expect(refreshes, 1);
    expect(inserts, 2);

    // 대기가 끝나면 다시 한 번 갱신하고, 또 거절되면 대기가 2배가 된다.
    now = fixedNow.add(const Duration(seconds: 60));
    await insert();
    expect(refreshes, 2);
    now = now.add(const Duration(seconds: 119));
    await insert();
    expect(refreshes, 2);
  });

  test('expires_in이 있으면 기기 시각 기준으로 만료를 계산한다', () {
    final session = SupabaseSession.fromAuthResponse({
      ...authBody(),
      'expires_at': fixedNow.millisecondsSinceEpoch ~/ 1000 - 7200,
    }, fixedNow);

    expect(session!.expiresAt, fixedNow.add(const Duration(hours: 1)));
    expect(session.isExpiredAt(fixedNow), isFalse);
  });
}
