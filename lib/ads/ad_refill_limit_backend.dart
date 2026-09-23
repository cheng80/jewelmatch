import '../game/item_kind.dart';
import '../services/backend/supabase_gateway.dart';

/// 서버가 알려 준 오늘의 보충 광고 상태.
class AdRefillStatus {
  const AdRefillStatus({
    required this.dailyLimit,
    required this.remaining,
    this.granted,
  });

  final int dailyLimit;
  final int remaining;

  /// claim 응답에서만 값이 있다.
  final bool? granted;

  static AdRefillStatus? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final limit = json['daily_limit'];
    final remaining = json['remaining'];
    if (limit is! num || remaining is! num) return null;
    final granted = json['granted'];
    return AdRefillStatus(
      dailyLimit: limit.toInt(),
      remaining: remaining.toInt(),
      granted: granted is bool ? granted : null,
    );
  }
}

/// 아이템 보충 광고의 하루 제한을 서버 날짜(KST)와 익명 사용자 기준으로 확인한다.
abstract interface class AdRefillLimitBackend {
  /// 실패하면 null. 호출자는 세션 로컬 제한으로 대신한다.
  Future<AdRefillStatus?> status();

  /// 보상 지급 기록. 실패하면 null.
  Future<AdRefillStatus?> claim(ItemKind item);
}

class SupabaseAdRefillLimitBackend implements AdRefillLimitBackend {
  SupabaseAdRefillLimitBackend(this._gateway);

  /// Supabase가 설정되지 않은 빌드에서는 null(세션 로컬 제한만 사용).
  static AdRefillLimitBackend? fromEnvironment() {
    final gateway = SupabaseGateway.instance;
    return gateway.isConfigured ? SupabaseAdRefillLimitBackend(gateway) : null;
  }

  final SupabaseGateway _gateway;

  @override
  Future<AdRefillStatus?> status() async {
    final result = await _gateway.rpc('ad_refill_status', const {});
    return result.isSuccess ? AdRefillStatus.fromJson(result.data) : null;
  }

  @override
  Future<AdRefillStatus?> claim(ItemKind item) async {
    final result = await _gateway.rpc('claim_ad_refill', {'p_item': item.name});
    return result.isSuccess ? AdRefillStatus.fromJson(result.data) : null;
  }
}
