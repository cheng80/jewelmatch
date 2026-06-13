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

class RankingService {
  RankingService._();

  static const String _baseUrl =
      'https://cheng80.myqnapcloud.com/matchranking/ranking.php';

  static Uri _uri(String action, RankingMode mode) {
    return Uri.parse('$_baseUrl?action=$action&mode=${mode.queryValue}');
  }

  static Future<RankingEntry?> fetchTop1({
    RankingMode mode = RankingMode.time,
  }) async {
    try {
      final res = await http
          .get(_uri('top1', mode))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['ok'] != true || body['top1'] == null) return null;
      if (mode == RankingMode.level &&
          body['mode'] != RankingMode.level.queryValue) {
        return null;
      }
      return RankingEntry.fromJson(body['top1'] as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<List<RankingEntry>> fetchList({
    RankingMode mode = RankingMode.time,
  }) async {
    try {
      final res = await http
          .get(_uri('list', mode))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return [];
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['ok'] != true) return [];
      if (mode == RankingMode.level &&
          body['mode'] != RankingMode.level.queryValue) {
        return [];
      }
      final list = body['ranking'] as List<dynamic>;
      return list
          .map((e) => RankingEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<SubmitResult?> submit({
    required RankingMode mode,
    required String name,
    required int score,
  }) async {
    try {
      final res = await http
          .post(
            _uri('submit', mode),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name,
              'score': score,
              'mode': mode.queryValue,
            }),
          )
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['ok'] != true) return null;
      return SubmitResult(
        ranked: body['ranked'] as bool,
        rank: (body['rank'] as num?)?.toInt(),
        score: (body['score'] as num?)?.toInt(),
        message: body['message'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}
