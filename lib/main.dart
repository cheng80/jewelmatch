import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app.dart';
import 'app_config.dart';
import 'game/components/board_atlas.dart';
import 'game/components/special_effect_burst.dart';
import 'resources/sound_manager.dart';
import 'services/backend/backend_bootstrap.dart';
import 'services/error_reporter.dart';
import 'services/ga4_analytics.dart';
import 'services/game_settings.dart';
import 'services/gameplay_config_service.dart';
import 'services/in_app_review_service.dart';
import 'services/wakelock_service.dart';
import 'utils/semantics_error_guard.dart';
import 'utils/storage_helper.dart';
import 'utils/web_loading.dart';

/// 앱 진입점.
/// main()은 초기화와 실행만 담당하고, 앱 설정(테마, 라우팅)은 App 위젯에 위임한다.
/// 오류 수집이 켜진 빌드는 본문 전체를 수집 zone에서 실행한다(PLAN-012).
void main() => ErrorReporter.instance.run(_main);

Future<void> _main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  installSemanticsErrorGuard(binding);
  AppConfig.validateStoreChannel();
  if (kIsWeb) {
    usePathUrlStrategy(); // /#/game → /game (hash 제거, path 기반 URL)
  }
  SoundManager.stopOrphansFromPreviousRun();
  await EasyLocalization.ensureInitialized();
  await StorageHelper.init();
  // 동의한 NAS 웹만 gtag.js를 뒤에서 싣는다. 로드를 기다리지 않는다(PLAN-011).
  Ga4Analytics.instance.setConsent(GameSettings.analyticsConsent);
  await InAppReviewService.saveFirstLaunchDateIfNeeded();
  GameplayConfigService.applyCached();
  unawaited(GameplayConfigService.refresh());
  unawaited(BackendBootstrap.start());
  if (kIsWeb) {
    unawaited(SoundManager.preload());
    unawaited(_preloadGameVisualAssets());
  } else {
    await Future.wait([SoundManager.preload(), _preloadGameVisualAssets()]);
  }
  _applyKeepScreenOn();
  runApp(
    ProviderScope(
      child: EasyLocalization(
        supportedLocales: const [
          Locale('ko'),
          Locale('en'),
          Locale('ja'),
          Locale('zh', 'CN'),
          Locale('zh', 'TW'),
        ],
        path: 'assets/translations',
        fallbackLocale: const Locale('ko'),
        saveLocale: true,
        child: const App(),
      ),
    ),
  );
  // 웹 HTML 로딩 화면: 붙잡은 화면(타이틀 준비, 게임 첫 보드)이 없으면 첫 프레임 뒤 걷는다.
  unawaited(
    WidgetsBinding.instance.waitUntilFirstFrameRasterized.then(
      (_) => WebLoadingScreen.markFirstFrame(),
    ),
  );
}

Future<void> _preloadGameVisualAssets() {
  return Future.wait([
    // 보드, 범위 효과, 게임 방법 화면이 같이 쓰는 한 장.
    BoardAtlas.load(),
    SpecialEffectBurst.preloadAreaEffectSprites(),
  ]);
}

/// 저장된 설정에 따라 화면 꺼짐 방지 적용.
void _applyKeepScreenOn() {
  WakelockService.apply(GameSettings.keepScreenOn);
}
