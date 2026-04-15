import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_config.dart';
import 'resources/sound_manager.dart';
import 'router.dart';
import 'theme/app_theme.dart';
import 'widgets/starry_background.dart';

/// 앱의 루트 위젯. 테마, 라우팅 등 앱 전체 설정을 담당한다.
class App extends StatelessWidget {
  const App({super.key});

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

    Widget root = Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Colors.black)),
          Positioned.fill(child: StarryBackground.instance),
          Positioned.fill(child: app),
        ],
      ),
    );

    if (kIsWeb) {
      root = Listener(
        onPointerDown: (_) => SoundManager.unlockForWeb(),
        onPointerUp: (_) => SoundManager.unlockForWeb(),
        behavior: HitTestBehavior.translucent,
        child: root,
      );
    }
    return root;
  }
}
