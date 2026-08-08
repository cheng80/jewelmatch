import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stonematch/services/ranking_service.dart';

http.Response jsonResponse(int statusCode, String body) => http.Response(
  body,
  statusCode,
  headers: {'content-type': 'application/json'},
);

void main() {
  group('랭킹 API 실패 유형', () {
    test('정상 목록, 빈 1위와 등록을 성공 결과로 반환한다', () async {
      final listClient = MockClient(
        (_) async => jsonResponse(
          200,
          '{"ok":true,"mode":"time","ranking":[{"name":"A","score":100}]}',
        ),
      );
      final topClient = MockClient(
        (_) async => jsonResponse(200, '{"ok":true,"mode":"time","top1":null}'),
      );
      final submitClient = MockClient((request) async {
        expect(request.method, 'POST');
        return jsonResponse(
          200,
          '{"ok":true,"mode":"time","ranked":true,"rank":1,"score":100}',
        );
      });

      final list = await RankingService.fetchList(client: listClient);
      final top = await RankingService.fetchTop1(client: topClient);
      final submit = await RankingService.submit(
        mode: RankingMode.time,
        name: 'A',
        score: 100,
        client: submitClient,
      );

      expect(list.isSuccess, isTrue);
      expect(list.data!.single.name, 'A');
      expect(top.isSuccess, isTrue);
      expect(top.data, isNull);
      expect(submit.isSuccess, isTrue);
      expect(submit.data!.rank, 1);
    });

    test('404를 기능 없음으로 구분한다', () async {
      final client = MockClient((_) async => jsonResponse(404, '{"ok":false}'));

      final result = await RankingService.fetchList(client: client);

      expect(result.failure, RankingFailure.notFound);
    });

    test('조회 실패 응답을 별도 유형으로 구분한다', () async {
      final client = MockClient(
        (_) async =>
            jsonResponse(500, '{"ok":false,"error":"ranking_load_failed"}'),
      );

      final result = await RankingService.fetchList(client: client);

      expect(result.failure, RankingFailure.loadFailed);
    });

    test('저장 실패 응답을 별도 유형으로 구분한다', () async {
      final client = MockClient(
        (_) async =>
            jsonResponse(500, '{"ok":false,"error":"ranking_save_failed"}'),
      );

      final result = await RankingService.submit(
        mode: RankingMode.time,
        name: 'A',
        score: 100,
        client: client,
      );

      expect(result.failure, RankingFailure.saveFailed);
    });

    test('잘못된 JSON과 네트워크 예외를 연결 불가로 구분한다', () async {
      final invalidJson = MockClient(
        (_) async => http.Response('not json', 200),
      );
      final offline = MockClient((_) async => throw Exception('offline'));

      final invalidResult = await RankingService.fetchList(client: invalidJson);
      final offlineResult = await RankingService.fetchList(client: offline);

      expect(invalidResult.failure, RankingFailure.unavailable);
      expect(offlineResult.failure, RankingFailure.unavailable);
    });
  });
}
