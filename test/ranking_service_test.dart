import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stonematch/services/backend/pocketbase_config.dart';
import 'package:stonematch/services/backend/pocketbase_gateway.dart';
import 'package:stonematch/services/ranking_service.dart';

const testConfig = PocketBaseConfig(url: 'https://pb.example');
const guestPath = '/api/stone-match/auth/guest';

http.Response jsonResponse(int status, Object? body) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, Object?> authBody() => {
  'token': 'token-1',
  'record': {'id': 'user-1'},
  'expires_in': 3600,
};

PocketBaseGateway gatewayWith(
  Future<http.Response> Function(http.Request request) handler,
) => PocketBaseGateway(config: testConfig, client: MockClient(handler));

void main() {
  group('랭킹 조회와 제출', () {
    test('목록과 1위는 로그인 없이 get_ranking을 부른다', () async {
      final requests = <http.Request>[];
      final gateway = gatewayWith((request) async {
        requests.add(request);
        final params = jsonDecode(request.body) as Map<String, dynamic>;
        return jsonResponse(
          200,
          params['p_limit'] == 1
              ? [
                  {'name': 'A', 'score': 300, 'ts': 1},
                ]
              : [
                  {'name': 'A', 'score': 300, 'ts': 1},
                  {'name': 'B', 'score': 200, 'ts': 2},
                ],
        );
      });

      final list = await RankingService.fetchList(
        mode: RankingMode.level,
        gateway: gateway,
      );
      final top = await RankingService.fetchTop1(gateway: gateway);

      expect(list.data!.map((e) => e.name), ['A', 'B']);
      expect(top.data!.score, 300);
      expect(
        requests.map((r) => r.url.path),
        everyElement('/api/stone-match/ranking/list'),
      );
      expect(requests.every((r) => r.headers['Authorization'] == null), isTrue);
      expect(jsonDecode(requests.first.body), {'p_mode': 'level'});
      expect(jsonDecode(requests.last.body), {'p_mode': 'time', 'p_limit': 1});
    });

    test('기록이 없으면 1위는 null 성공이다', () async {
      final gateway = gatewayWith((_) async => jsonResponse(200, []));

      final top = await RankingService.fetchTop1(gateway: gateway);

      expect(top.isSuccess, isTrue);
      expect(top.data, isNull);
    });

    test('제출은 익명 가입 뒤 사용자 토큰으로 submit_ranking을 부른다', () async {
      final paths = <String>[];
      final gateway = gatewayWith((request) async {
        paths.add(request.url.path);
        if (request.url.path == guestPath) {
          return jsonResponse(200, authBody());
        }
        expect(request.headers['Authorization'], 'token-1');
        expect(jsonDecode(request.body), {
          'p_mode': 'time',
          'p_name': 'A',
          'p_score': 100,
        });
        return jsonResponse(200, {
          'mode': 'time',
          'ranked': true,
          'rank': 1,
          'score': 100,
        });
      });

      final result = await RankingService.submit(
        mode: RankingMode.time,
        name: 'A',
        score: 100,
        gateway: gateway,
      );

      expect(result.data!.ranked, isTrue);
      expect(result.data!.rank, 1);
      expect(paths, [guestPath, '/api/stone-match/ranking/submit']);
    });
  });

  group('랭킹 실패 유형', () {
    test('404를 기능 없음으로 구분한다', () async {
      final gateway = gatewayWith(
        (_) async => jsonResponse(404, {'code': 'not_found'}),
      );

      final result = await RankingService.fetchList(gateway: gateway);

      expect(result.failure, RankingFailure.notFound);
    });

    test('조회 서버 오류를 조회 실패로 구분한다', () async {
      final gateway = gatewayWith(
        (_) async => jsonResponse(500, {'message': 'boom'}),
      );

      final result = await RankingService.fetchList(gateway: gateway);

      expect(result.failure, RankingFailure.loadFailed);
    });

    test('제약 위반과 제출 과다를 저장 실패로 구분한다', () async {
      for (final status in [400, 429]) {
        final gateway = gatewayWith((request) async {
          if (request.url.path == guestPath) {
            return jsonResponse(200, authBody());
          }
          return jsonResponse(status, {'code': 'rejected'});
        });

        final result = await RankingService.submit(
          mode: RankingMode.time,
          name: 'A',
          score: 100,
          gateway: gateway,
        );

        expect(result.failure, RankingFailure.saveFailed);
      }
    });

    test('잘못된 응답, 네트워크 예외, 미설정 빌드를 연결 불가로 구분한다', () async {
      // 비JSON 본문은 gateway가 server 실패로 분류한다(pocketbase_gateway_test). 여기서는 형태가 틀린 JSON.
      final invalid = gatewayWith(
        (_) async => jsonResponse(200, {'not': 'a list'}),
      );
      final offline = gatewayWith((_) async => throw Exception('offline'));
      final unconfigured = PocketBaseGateway(
        config: const PocketBaseConfig(url: ''),
      );

      final invalidResult = await RankingService.fetchList(gateway: invalid);
      final offlineResult = await RankingService.fetchList(gateway: offline);
      final unconfiguredResult = await RankingService.submit(
        mode: RankingMode.level,
        name: 'A',
        score: 3,
        gateway: unconfigured,
      );

      expect(invalidResult.failure, RankingFailure.unavailable);
      expect(offlineResult.failure, RankingFailure.unavailable);
      expect(unconfiguredResult.failure, RankingFailure.unavailable);
    });
  });
}
