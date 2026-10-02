import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stonematch/services/backend/backend_gateway.dart';
import 'package:stonematch/services/backend/backend_selector.dart';
import 'package:stonematch/services/backend/pocketbase_config.dart';
import 'package:stonematch/services/backend/pocketbase_gateway.dart';
import 'package:stonematch/services/backend/pocketbase_session_store.dart';
import 'package:stonematch/services/ranking_service.dart';
import 'package:stonematch/ads/ad_refill_limit_backend.dart';
import 'package:stonematch/game/item_kind.dart';

const config = PocketBaseConfig(url: 'https://pb.example');
http.Response reply(Object? body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);
Map<String, Object?> auth([String token = 'token']) => {
  'token': token,
  'record': {'id': 'player'},
  'expires_in': 604800,
};

class FailingStore extends MemoryPocketBaseSessionStore {
  @override
  Future<void> write(String scope, PocketBaseIdentity identity) async =>
      throw StateError('disk');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('app backend is PocketBase only and rejects unsafe URLs', () async {
    expect(BackendSelector.instance, isA<PocketBaseGateway>());
    // 설정 없는 빌드: 네트워크 없이 notConfigured로 끝나 게임은 로컬로 진행한다.
    expect(BackendSelector.instance.isConfigured, false);
    var calls = 0;
    final unconfigured = PocketBaseGateway(
      config: const PocketBaseConfig(url: ''),
      client: MockClient((_) async {
        calls++;
        return reply(auth());
      }),
    );
    for (final result in [
      await unconfigured.ensureSession(),
      await unconfigured.rpc('get_ranking', {}, requireAuth: false),
      await unconfigured.insert('game_events', []),
      await unconfigured.select('app_config?key=eq.gameplay&select=value'),
    ]) {
      expect(result.failure, BackendFailure.notConfigured);
    }
    expect(calls, 0);
    for (final url in [
      'http://pb.example',
      'https://a:b@pb.example',
      'https://pb.example?q=x',
      'https://pb.example#x',
    ]) {
      expect(PocketBaseConfig(url: url).isConfigured, false);
    }
  });
  test(
    'secure credentials persisted before auth and reused after expiry/restart',
    () async {
      final store = MemoryPocketBaseSessionStore();
      var now = DateTime.utc(2026);
      final credentials = <Object?>[];
      final client = MockClient((request) async {
        final body = jsonDecode(request.body);
        final stored = await store.readLatest(config.baseUrl);
        expect(stored, isNotNull);
        expect(body, stored!.credentials);
        expect(body['device_id'], matches(r'^[0-9a-f]{32}$'));
        expect(body['device_secret'], matches(r'^[0-9a-f]{64}$'));
        credentials.add(body);
        return reply(auth());
      });
      PocketBaseGateway gateway() => PocketBaseGateway(
        config: config,
        sessionStore: store,
        client: client,
        now: () => now,
      );
      final first = gateway();
      final results = await Future.wait(
        List.generate(8, (_) => first.ensureSession()),
      );
      expect(results.every((r) => r.isSuccess), true);
      expect(credentials.length, 1);
      expect((await gateway().ensureSession()).data!.userId, 'player');
      expect(credentials.length, 1);
      now = now.add(const Duration(days: 8));
      expect((await gateway().ensureSession()).isSuccess, true);
      expect(credentials, [credentials.first, credentials.first]);
    },
  );
  test('storage failure prevents network', () async {
    var calls = 0;
    final gateway = PocketBaseGateway(
      config: config,
      sessionStore: FailingStore(),
      client: MockClient((_) async {
        calls++;
        return reply(auth());
      }),
    );
    expect((await gateway.ensureSession()).isSuccess, false);
    expect(calls, 0);
  });
  test(
    'network failures preserve credentials and enforce retry delay',
    () async {
      final store = MemoryPocketBaseSessionStore();
      var now = DateTime.utc(2026);
      var calls = 0;
      final bodies = <String>[];
      final gateway = PocketBaseGateway(
        config: config,
        sessionStore: store,
        now: () => now,
        client: MockClient((r) async {
          calls++;
          bodies.add(r.body);
          throw http.ClientException('offline');
        }),
      );
      expect((await gateway.ensureSession()).failure, BackendFailure.network);
      await gateway.ensureSession();
      expect(calls, 1);
      now = now.add(const Duration(seconds: 11));
      await gateway.ensureSession();
      expect(bodies, [bodies.first, bodies.first]);
    },
  );
  test(
    'persistent 401 retries once then backs off without new identity',
    () async {
      var authCalls = 0;
      var dataCalls = 0;
      final bodies = <String>[];
      final gateway = PocketBaseGateway(
        config: config,
        client: MockClient((r) async {
          if (r.url.path.endsWith('/auth/guest')) {
            bodies.add(r.body);
            return reply(auth('token-${++authCalls}'));
          }
          dataCalls++;
          return reply({}, 401);
        }),
      );
      expect(
        (await gateway.rpc('ad_refill_status', {})).failure,
        BackendFailure.unauthorized,
      );
      await gateway.rpc('ad_refill_status', {});
      expect(authCalls, 2);
      expect(dataCalls, 2);
      expect(bodies[0], bodies[1]);
    },
  );
  test('recovered same token is reused after a successful retry', () async {
    var authCalls = 0;
    var dataCalls = 0;
    final gateway = PocketBaseGateway(
      config: config,
      client: MockClient((r) async {
        if (r.url.path.endsWith('/auth/guest')) {
          authCalls++;
          return reply(auth());
        }
        dataCalls++;
        return reply({}, dataCalls == 1 ? 401 : 200);
      }),
    );
    expect((await gateway.rpc('ad_refill_status', {})).isSuccess, true);
    expect((await gateway.rpc('ad_refill_status', {})).isSuccess, true);
    expect(authCalls, 2);
    expect(dataCalls, 3);
  });
  test(
    'retention replacement persists new player with the same device credentials',
    () async {
      final store = MemoryPocketBaseSessionStore();
      final identity = PocketBaseIdentity.generate().withSession(
        PocketBaseSession(
          token: 'expired',
          userId: 'retained-old-player',
          expiresAt: DateTime.utc(2000),
        ),
      );
      await store.write(config.baseUrl, identity);
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        expect(jsonDecode(request.body), identity.credentials);
        return reply(auth());
      });
      PocketBaseGateway gateway() => PocketBaseGateway(
        config: config,
        sessionStore: store,
        client: client,
      );
      expect((await gateway().ensureSession()).data!.userId, 'player');
      final saved = (await store.readLatest(config.baseUrl))!;
      expect(saved.credentials, identity.credentials);
      expect(saved.session!.userId, 'player');
      expect((await gateway().ensureSession()).data!.userId, 'player');
      expect(calls, 1);
    },
  );
  test(
    'failed retention auth preserves old session and device across restart',
    () async {
      for (final status in [400, 401, 429, 500, null]) {
        final store = MemoryPocketBaseSessionStore();
        final identity = PocketBaseIdentity.generate().withSession(
          PocketBaseSession(
            token: 'expired',
            userId: 'old-player',
            expiresAt: DateTime.utc(2000),
          ),
        );
        await store.write(config.baseUrl, identity);
        var calls = 0;
        final client = MockClient((request) async {
          calls++;
          expect(jsonDecode(request.body), identity.credentials);
          if (status == null) throw http.ClientException('offline');
          return reply({}, status);
        });
        PocketBaseGateway gateway() => PocketBaseGateway(
          config: config,
          sessionStore: store,
          client: client,
        );
        final first = gateway();
        expect((await first.ensureSession()).isSuccess, false);
        expect((await first.ensureSession()).isSuccess, false);
        expect(calls, 1);
        expect((await gateway().ensureSession()).isSuccess, false);
        expect(calls, 2);
        expect(
          (await store.readLatest(config.baseUrl))!.toJson(),
          identity.toJson(),
        );
      }
    },
  );
  test('stored session rejects unsafe tokens and out-of-range timestamps', () {
    final valid = PocketBaseSession(
      token: 'valid-token',
      userId: 'player',
      expiresAt: DateTime.utc(2026),
    ).toJson();
    expect(PocketBaseSession.fromJson(valid), isNotNull);
    for (final token in [
      ' bad',
      'bad token',
      'bad\tvalue',
      'bad\r\nvalue',
      'bad\u0000value',
      'bad\u007fvalue',
    ]) {
      expect(PocketBaseSession.fromJson({...valid, 'token': token}), isNull);
    }
    for (final expiry in [
      -1,
      253402300800000,
      8640000000000001,
      -8640000000000001,
      1e100,
      'invalid',
      null,
    ]) {
      expect(
        PocketBaseSession.fromJson({...valid, 'expires_at': expiry}),
        isNull,
      );
      final identity = PocketBaseIdentity.generate();
      final decoded = PocketBaseIdentity.fromJson({
        ...identity.toJson(),
        'session': {...valid, 'expires_at': expiry},
      });
      expect(decoded.session, isNull);
      expect(decoded.credentials, identity.credentials);
    }
  });
  test('malformed auth never accepted', () async {
    for (final body in [
      null,
      {},
      auth(''),
      auth('bad token'),
      {...auth(), 'record': {}},
      {...auth(), 'expires_in': -1},
      {...auth(), 'expires_in': '604800'},
    ]) {
      final gateway = PocketBaseGateway(
        config: config,
        client: MockClient((_) async => reply(body)),
      );
      expect((await gateway.ensureSession()).failure, BackendFailure.server);
      expect(gateway.currentUserId, isNull);
    }
  });
  test(
    'API mapping, service injection, public reads and forced private auth',
    () async {
      final paths = <String>[];
      final gateway = PocketBaseGateway(
        config: config,
        client: MockClient((r) async {
          paths.add(r.url.path);
          expect(r.headers.containsKey('apikey'), false);
          switch (r.url.path.split('/').last) {
            case 'guest':
              return reply(auth());
            case 'list':
              expect(r.headers.containsKey('Authorization'), false);
              expect(jsonDecode(r.body)['p_mode'], 'time');
              return reply([
                {'name': 'name', 'score': 12, 'ts': 1790000000},
              ]);
            case 'gameplay':
              expect(r.method, 'GET');
              return reply([
                {'value': {}},
              ]);
            default:
              expect(r.headers['Authorization'], 'token');
              if (r.url.path.endsWith('/events')) {
                expect(jsonDecode(r.body), [
                  {'name': 'test'},
                ]);
                return http.Response('', 204);
              }
              return reply({'daily_limit': 3, 'remaining': 2, 'granted': true});
          }
        }),
      );
      expect(
        (await RankingService.fetchList(gateway: gateway)).isSuccess,
        true,
      );
      final ads = RemoteAdRefillLimitBackend(gateway);
      expect((await ads.status())!.remaining, 2);
      expect((await ads.claim(ItemKind.values.first))!.granted, true);
      await gateway.rpc('submit_ranking', {'p_score': 2}, requireAuth: false);
      expect(
        (await gateway.insert('game_events', [
          {'name': 'test'},
        ])).isSuccess,
        true,
      );
      await gateway.select('app_config?key=eq.gameplay&select=value');
      expect(paths, [
        '/api/stone-match/ranking/list',
        '/api/stone-match/auth/guest',
        '/api/stone-match/ads/status',
        '/api/stone-match/ads/claim',
        '/api/stone-match/ranking/submit',
        '/api/stone-match/events',
        '/api/stone-match/config/gameplay',
      ]);
      expect((await gateway.rpc('other', {})).failure, BackendFailure.rejected);
      expect(
        (await gateway.insert('users', [])).failure,
        BackendFailure.rejected,
      );
      expect((await gateway.select('users')).failure, BackendFailure.rejected);
      expect(paths.length, 7);
    },
  );
  test(
    'auth rejection backs off, doubles the wait and ends on clock rollback',
    () async {
      var now = DateTime.utc(2026);
      var calls = 0;
      var fail = true;
      final gateway = PocketBaseGateway(
        config: config,
        now: () => now,
        client: MockClient((_) async {
          calls++;
          return fail ? reply({}, 400) : reply(auth());
        }),
      );
      expect((await gateway.ensureSession()).failure, BackendFailure.rejected);
      now = now.add(const Duration(seconds: 59));
      expect(
        (await gateway.rpc('ad_refill_status', {})).failure,
        BackendFailure.rejected,
      );
      expect(calls, 1);
      now = now.add(const Duration(seconds: 1));
      await gateway.ensureSession();
      expect(calls, 2);
      // 두 번째 실패 뒤에는 120초를 기다린다.
      now = now.add(const Duration(seconds: 119));
      await gateway.ensureSession();
      expect(calls, 2);
      // 시계를 되돌려 대기 끝이 10분보다 멀어지면 대기를 끝낸다.
      now = now.subtract(const Duration(days: 1));
      fail = false;
      expect((await gateway.ensureSession()).isSuccess, true);
      expect(calls, 3);
    },
  );
  test(
    'insert never sends when the session user differs from expectedUserId',
    () async {
      final paths = <String>[];
      final gateway = PocketBaseGateway(
        config: config,
        client: MockClient((r) async {
          paths.add(r.url.path);
          return r.url.path.endsWith('/auth/guest')
              ? reply(auth())
              : reply({}, 204);
        }),
      );
      final mismatch = await gateway.insert('game_events', [
        {'name': 'a'},
      ], expectedUserId: 'someone-else');
      expect(mismatch.failure, BackendFailure.unauthorized);
      expect(mismatch.errorCode, BackendGateway.ownerMismatch);
      expect(paths, ['/api/stone-match/auth/guest']);

      final match = await gateway.insert('game_events', [
        {'name': 'a'},
      ], expectedUserId: 'player');
      expect(match.isSuccess, true);
      expect(paths.last, '/api/stone-match/events');
    },
  );
  test('403 is rejected without re-authenticating', () async {
    final paths = <String>[];
    final gateway = PocketBaseGateway(
      config: config,
      client: MockClient((r) async {
        paths.add(r.url.path);
        return r.url.path.endsWith('/auth/guest')
            ? reply(auth())
            : reply({}, 403);
      }),
    );
    final result = await gateway.insert('game_events', [
      {'name': 'a'},
    ]);
    expect(result.failure, BackendFailure.rejected);
    expect(paths, ['/api/stone-match/auth/guest', '/api/stone-match/events']);
  });
  test(
    'HTTP errors and invalid JSON map without leaking server details',
    () async {
      for (final entry in {
        400: BackendFailure.rejected,
        401: BackendFailure.unauthorized,
        403: BackendFailure.rejected,
        404: BackendFailure.notFound,
        429: BackendFailure.rateLimited,
        500: BackendFailure.server,
      }.entries) {
        final gateway = PocketBaseGateway(
          config: config,
          client: MockClient(
            (_) async => reply({'message': 'private'}, entry.key),
          ),
        );
        final result = await gateway.rpc('get_ranking', {});
        expect(result.failure, entry.value);
        expect(result.errorMessage, isNull);
      }
      final gateway = PocketBaseGateway(
        config: config,
        client: MockClient((_) async => http.Response('bad', 200)),
      );
      expect(
        (await gateway.rpc('get_ranking', {})).failure,
        BackendFailure.server,
      );
    },
  );
  test(
    'production domain rename preserves device identity and refreshes at new host',
    () async {
      SharedPreferences.setMockInitialValues({});
      const oldUrl = 'https://stonematch.fastmake.net';
      const newConfig = PocketBaseConfig(
        url: 'https://stonematch-pb.fastmake.net/',
      );
      const store = PrefsPocketBaseSessionStore();
      var now = DateTime.utc(2026, 10, 2);
      final identity = PocketBaseIdentity.generate().withSession(
        PocketBaseSession(
          token: 'existing-token',
          userId: 'player',
          expiresAt: now.add(const Duration(days: 1)),
        ),
      );
      await store.write(oldUrl, identity);
      var calls = 0;
      final gateway = PocketBaseGateway(
        config: newConfig,
        sessionStore: store,
        now: () => now,
        client: MockClient((request) async {
          calls++;
          expect(request.url.host, 'stonematch-pb.fastmake.net');
          expect(jsonDecode(request.body), identity.credentials);
          return reply(auth('refreshed-token'));
        }),
      );
      expect((await gateway.ensureSession()).data!.token, 'existing-token');
      expect(calls, 0);
      now = now.add(const Duration(days: 2));
      expect((await gateway.ensureSession()).data!.token, 'refreshed-token');
      expect(calls, 1);
      final saved = (await store.readLatest(oldUrl))!;
      expect(saved.credentials, identity.credentials);
      expect(saved.session!.userId, 'player');
      expect(saved.session!.token, 'refreshed-token');
      expect(await store.readLatest('https://other.example'), isNull);
      expect(
        await store.readLatest('https://stonematch-pb.fastmake.net/other'),
        isNull,
      );
    },
  );
  test('domain rename does not replace corrupt existing credentials', () async {
    const oldUrl = 'https://stonematch.fastmake.net';
    SharedPreferences.setMockInitialValues({
      PrefsPocketBaseSessionStore.keyFor(oldUrl): '{}',
    });
    var calls = 0;
    final gateway = PocketBaseGateway(
      config: const PocketBaseConfig(url: 'https://stonematch-pb.fastmake.net'),
      sessionStore: const PrefsPocketBaseSessionStore(),
      client: MockClient((_) async {
        calls++;
        return reply(auth());
      }),
    );
    expect((await gateway.ensureSession()).isSuccess, false);
    expect(calls, 0);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PrefsPocketBaseSessionStore.keyFor(oldUrl)), '{}');
  });
  test(
    'preferences reload latest token, isolate URL and preserve legacy storage',
    () async {
      SharedPreferences.setMockInitialValues({'supabase_session': 'untouched'});
      const store = PrefsPocketBaseSessionStore();
      final identity = PocketBaseIdentity.generate();
      await store.write(config.baseUrl, identity);
      final gateway = PocketBaseGateway(
        config: config,
        sessionStore: store,
        client: MockClient((_) async => reply(auth('first'))),
      );
      await gateway.ensureSession();
      final latest = identity.withSession(
        PocketBaseSession(
          token: 'other-tab',
          userId: 'player',
          expiresAt: DateTime.now().add(const Duration(days: 2)),
        ),
      );
      await store.write(config.baseUrl, latest);
      expect((await gateway.ensureSession()).data!.token, 'other-tab');
      expect(await store.readLatest('https://other.example'), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('supabase_session'), 'untouched');
      await prefs.setString(
        PrefsPocketBaseSessionStore.keyFor(config.baseUrl),
        '{}',
      );
      expect((await gateway.ensureSession()).isSuccess, false);
      expect(
        prefs.getString(PrefsPocketBaseSessionStore.keyFor(config.baseUrl)),
        '{}',
      );
    },
  );
}
