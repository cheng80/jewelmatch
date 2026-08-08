import 'dart:convert';
import 'package:http/http.dart' as http;

enum RankingMode {
  level('level'),
  time('time');

  const RankingMode(this.queryValue);

  final String queryValue;
}

class RankingEntry {
  RankingEntry({required this.name, required this.score, this.ts});
  final String name;
  final int score;
  final int? ts;

  factory RankingEntry.fromJson(Map<String, dynamic> j) => RankingEntry(
    name: j['name'] as String,
    score: (j['score'] as num).toInt(),
    ts: (j['ts'] as num?)?.toInt(),
  );
}

class SubmitResult {
  SubmitResult({required this.ranked, this.rank, this.score, this.message});
  final bool ranked;
  final int? rank;
  final int? score;
  final String? message;
}

enum RankingFailure { notFound, loadFailed, saveFailed, unavailable }

class RankingResult<T> {
  const RankingResult.success(this.data) : failure = null;
  const RankingResult.failure(this.failure) : data = null;

  final T? data;
  final RankingFailure? failure;

  bool get isSuccess => failure == null;
}

class RankingService {
  RankingService._();

  static const String _baseUrl =
      'https://cheng80.myqnapcloud.com/matchranking/ranking.php';

  static Uri _uri(String action, RankingMode mode) {
    return Uri.parse('$_baseUrl?action=$action&mode=${mode.queryValue}');
  }

  static RankingFailure? _serverFailure(Map<String, dynamic> body) {
    return switch (body['error']) {
      'ranking_load_failed' => RankingFailure.loadFailed,
      'ranking_save_failed' => RankingFailure.saveFailed,
      _ => null,
    };
  }

  static Future<RankingResult<Map<String, dynamic>>> _request(
    String action,
    RankingMode mode, {
    Map<String, dynamic>? jsonBody,
    http.Client? client,
  }) async {
    final ownsClient = client == null;
    final requestClient = client ?? http.Client();
    try {
      final uri = _uri(action, mode);
      final res =
          await (jsonBody == null
                  ? requestClient.get(uri)
                  : requestClient.post(
                      uri,
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode(jsonBody),
                    ))
              .timeout(const Duration(seconds: 6));
      if (res.statusCode == 404) {
        return const RankingResult.failure(RankingFailure.notFound);
      }

      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) {
        return const RankingResult.failure(RankingFailure.unavailable);
      }
      final failure = _serverFailure(decoded);
      if (failure != null) return RankingResult.failure(failure);
      if (res.statusCode != 200 || decoded['ok'] != true) {
        return const RankingResult.failure(RankingFailure.unavailable);
      }
      return RankingResult.success(decoded);
    } catch (_) {
      return const RankingResult.failure(RankingFailure.unavailable);
    } finally {
      if (ownsClient) requestClient.close();
    }
  }

  static Future<RankingResult<RankingEntry?>> fetchTop1({
    RankingMode mode = RankingMode.time,
    http.Client? client,
  }) async {
    final result = await _request('top1', mode, client: client);
    if (!result.isSuccess) return RankingResult.failure(result.failure!);
    try {
      final body = result.data!;
      if (body['mode'] != mode.queryValue) {
        return const RankingResult.failure(RankingFailure.unavailable);
      }
      final top1 = body['top1'];
      if (top1 == null) return const RankingResult.success(null);
      return RankingResult.success(
        RankingEntry.fromJson(top1 as Map<String, dynamic>),
      );
    } catch (_) {
      return const RankingResult.failure(RankingFailure.unavailable);
    }
  }

  static Future<RankingResult<List<RankingEntry>>> fetchList({
    RankingMode mode = RankingMode.time,
    http.Client? client,
  }) async {
    final result = await _request('list', mode, client: client);
    if (!result.isSuccess) return RankingResult.failure(result.failure!);
    try {
      final body = result.data!;
      if (body['mode'] != mode.queryValue) {
        return const RankingResult.failure(RankingFailure.unavailable);
      }
      final list = body['ranking'] as List<dynamic>;
      return RankingResult.success(
        list
            .map((e) => RankingEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } catch (_) {
      return const RankingResult.failure(RankingFailure.unavailable);
    }
  }

  static Future<RankingResult<SubmitResult>> submit({
    required RankingMode mode,
    required String name,
    required int score,
    http.Client? client,
  }) async {
    final result = await _request(
      'submit',
      mode,
      client: client,
      jsonBody: {'name': name, 'score': score, 'mode': mode.queryValue},
    );
    if (!result.isSuccess) return RankingResult.failure(result.failure!);
    try {
      final body = result.data!;
      if (body['mode'] != mode.queryValue) {
        return const RankingResult.failure(RankingFailure.unavailable);
      }
      return RankingResult.success(
        SubmitResult(
          ranked: body['ranked'] as bool,
          rank: (body['rank'] as num?)?.toInt(),
          score: (body['score'] as num?)?.toInt(),
          message: body['message'] as String?,
        ),
      );
    } catch (_) {
      return const RankingResult.failure(RankingFailure.unavailable);
    }
  }
}
