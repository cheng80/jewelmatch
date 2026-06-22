import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flame/flame.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app.dart';
import 'resources/asset_paths.dart';
import 'resources/sound_manager.dart';
import 'services/game_settings.dart';
import 'services/in_app_review_service.dart';
import 'services/wakelock_service.dart';
import 'utils/storage_helper.dart';
import 'widgets/sprite_sheet_frame.dart';

/// 앱 진입점.
/// main()은 초기화와 실행만 담당하고, 앱 설정(테마, 라우팅)은 App 위젯에 위임한다.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    usePathUrlStrategy(); // /#/game → /game (hash 제거, path 기반 URL)
  }
  await EasyLocalization.ensureInitialized();
  await StorageHelper.init();
  await InAppReviewService.saveFirstLaunchDateIfNeeded();
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
}

Future<void> _preloadGameVisualAssets() {
  return Future.wait([
    Flame.images.load(AssetPaths.jewelSpriteSheet),
    Flame.images.load(AssetPaths.specialSpriteSheet),
    Flame.images.load(AssetPaths.specialActionSpriteSheet),
    SpriteSheetFrame.precache('assets/images/${AssetPaths.jewelSpriteSheet}'),
    SpriteSheetFrame.precache('assets/images/${AssetPaths.specialSpriteSheet}'),
    SpriteSheetFrame.precache(
      'assets/images/${AssetPaths.specialActionSpriteSheet}',
    ),
  ]);
}

/// 저장된 설정에 따라 화면 꺼짐 방지 적용.
void _applyKeepScreenOn() {
  WakelockService.apply(GameSettings.keepScreenOn);
}
