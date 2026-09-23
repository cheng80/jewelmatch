import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../app_config.dart';
import '../game/gameplay_flags.dart';
import '../utils/storage_helper.dart';
import 'backend/supabase_gateway.dart';

/// 실험 기능 스위치 적용. 캐시를 먼저 쓰고 원격 `app_config.gameplay`로 갱신한다.
///
/// 웹의 `?exp=`는 항상 마지막에 덮어쓰며 캐시에는 남기지 않는다. 판 도중 값은
/// `board.flags`가 판 시작 때 복사하므로 바뀐 값은 다음 새 판부터 쓰인다.
/// 모든 실패는 조용히 캐시나 기본값으로 둔다(BR-002).
class GameplayConfigService {
  GameplayConfigService._();

  static const String configKey = 'gameplay';

  /// 웹 URL의 `exp` 값. 테스트에서 바꾼다.
  @visibleForTesting
  static String? Function() urlOverride = _urlExp;

  static String? _urlExp() => kIsWeb ? Uri.base.queryParameters['exp'] : null;

  /// 캐시(없으면 기본값) 위에 URL 덮어쓰기를 적용한다. StorageHelper.init() 뒤에 부른다.
  static void applyCached() {
    GameplayFlags base = const GameplayFlags();
    try {
      final raw = StorageHelper.read<String>(StorageKeys.gameplayFlags);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, Object?>) {
          base = GameplayFlags.fromJson(decoded);
        }
      }
    } catch (_) {
      // 깨진 캐시는 기본값으로 둔다.
    }
    _apply(base);
  }

  /// 원격 값을 받아 캐시와 현재 값을 갱신한다. 실패하면 지금 값을 유지한다.
  static Future<void> refresh({SupabaseGateway? gateway}) async {
    final backend = gateway ?? SupabaseGateway.instance;
    final result = await backend.select(
      'app_config?key=eq.$configKey&select=value',
    );
    final rows = result.data;
    if (!result.isSuccess || rows is! List || rows.isEmpty) return;
    final row = rows.first;
    final value = row is Map<String, dynamic> ? row['value'] : null;
    if (value is! Map<String, dynamic>) return;
    final remote = GameplayFlags.fromJson(value);
    try {
      await StorageHelper.write(
        StorageKeys.gameplayFlags,
        jsonEncode(remote.toJson()),
      );
    } catch (_) {
      // 저장 실패는 다음 실행에서 다시 받는다.
    }
    _apply(remote);
  }

  static void _apply(GameplayFlags base) {
    GameplayFlags.current = base.withUrlOverride(urlOverride());
  }
}
