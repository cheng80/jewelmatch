import 'backend/supabase_gateway.dart';

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

/// 게임 내 랭킹(타임 점수, 레벨 완료 수). 저장소는 Supabase(ADR-009).
///
/// - 조회는 공개용 키만으로 anon 역할로 `get_ranking`을 부른다.
/// - 제출은 익명 로그인 뒤 `submit_ranking`을 부른다.
/// - 실패는 기존 4가지 유형으로 돌려주며 플레이와 나가기를 막지 않는다(BR-002).
class RankingService {
  RankingService._();

  static Future<RankingResult<RankingEntry?>> fetchTop1({
    RankingMode mode = RankingMode.time,
    SupabaseGateway? gateway,
  }) async {
    final result = await _list(mode, limit: 1, gateway: gateway);
    if (!result.isSuccess) return RankingResult.failure(result.failure!);
    final list = result.data!;
    return RankingResult.success(list.isEmpty ? null : list.first);
  }

  static Future<RankingResult<List<RankingEntry>>> fetchList({
    RankingMode mode = RankingMode.time,
    SupabaseGateway? gateway,
  }) {
    return _list(mode, gateway: gateway);
  }

  static Future<RankingResult<List<RankingEntry>>> _list(
    RankingMode mode, {
    int? limit,
    SupabaseGateway? gateway,
  }) async {
    final backend = gateway ?? SupabaseGateway.instance;
    final result = await backend.rpc('get_ranking', {
      'p_mode': mode.queryValue,
      'p_limit': ?limit,
    }, requireAuth: false);
    if (!result.isSuccess) {
      return RankingResult.failure(_failureFor(result.failure!, save: false));
    }
    try {
      final rows = result.data as List<dynamic>;
      return RankingResult.success(
        rows
            .map((row) => RankingEntry.fromJson(row as Map<String, dynamic>))
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
    SupabaseGateway? gateway,
  }) async {
    final backend = gateway ?? SupabaseGateway.instance;
    final result = await backend.rpc('submit_ranking', {
      'p_mode': mode.queryValue,
      'p_name': name,
      'p_score': score,
    });
    if (!result.isSuccess) {
      return RankingResult.failure(_failureFor(result.failure!, save: true));
    }
    try {
      final body = result.data as Map<String, dynamic>;
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

  static RankingFailure _failureFor(
    BackendFailure failure, {
    required bool save,
  }) {
    return switch (failure) {
      BackendFailure.notFound => RankingFailure.notFound,
      BackendFailure.server ||
      BackendFailure.rejected ||
      BackendFailure.rateLimited =>
        save ? RankingFailure.saveFailed : RankingFailure.loadFailed,
      BackendFailure.notConfigured ||
      BackendFailure.network ||
      BackendFailure.unauthorized => RankingFailure.unavailable,
    };
  }
}
