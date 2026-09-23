import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../event_logger.dart';
import 'supabase_gateway.dart';

/// 앱 시작 시 Supabase 준비. 게임 시작을 막지 않도록 main에서 기다리지 않고 호출한다.
class BackendBootstrap {
  BackendBootstrap._();

  static Future<void> start({
    SupabaseGateway? gateway,
    EventLogger? logger,
  }) async {
    final backend = gateway ?? SupabaseGateway.instance;
    if (!backend.isConfigured) return;
    final events = logger ?? EventLogger.instance;
    try {
      final info = await PackageInfo.fromPlatform();
      events.appVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {
      // 버전 조회 실패는 빈 값으로 둔다.
    }
    await backend.ensureSession();
    events.attachLifecycleFlush();
    events.log('session_start', {
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
    });
  }
}
