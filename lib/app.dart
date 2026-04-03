import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_config.dart';
import 'resources/sound_manager.dart';
import 'router.dart';
import 'theme/app_theme.dart';

/// 앱의 루트 위젯. 테마, 라우팅 등 앱 전체 설정을 담당한다.
/// main.dart와 분리한 이유:
///   - main()에 초기화 코드가 늘어나도(Firebase, 환경변수 등) 이 파일은 변경 없이 유지된다.
///   - ProviderScope 등 래퍼가 추가될 때 main()에서 감싸면 되므로 관심사가 분리된다.
class App extends StatelessWidget {
  const App({super.key});

  /// MaterialApp.router로 테마·라우팅 설정.
  @override
  Widget build(BuildContext context) {
    final app = MaterialApp.router(
      title: AppConfig.appTitle,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: buildAppTheme(),
      routerConfig: appRouter,
    );
    if (kIsWeb) {
      return Listener(
        onPointerDown: (_) => SoundManager.unlockForWeb(),
        behavior: HitTestBehavior.translucent,
        child: app,
      );
    }
    return app;
  }
}
