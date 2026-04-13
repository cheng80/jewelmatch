import 'dart:convert';
import 'package:http/http.dart' as http;

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

  static Future<RankingEntry?> fetchTop1() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl?action=top1'))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['ok'] != true || body['top1'] == null) return null;
      return RankingEntry.fromJson(body['top1'] as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<List<RankingEntry>> fetchList() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl?action=list'))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return [];
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['ok'] != true) return [];
      final list = body['ranking'] as List<dynamic>;
      return list
          .map((e) => RankingEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<SubmitResult?> submit({
    required String name,
    required int score,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl?action=submit'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'name': name, 'score': score}),
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
