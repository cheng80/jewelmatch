import 'package:flutter/foundation.dart';

import 'web_loading_bridge_stub.dart'
    if (dart.library.js_interop) 'web_loading_bridge_web.dart';

/// 웹 로딩 화면(web/index.html의 #sm-loading)을 붙잡고 놓는다.
///
/// 웹만 해당한다. 게임 화면과 타이틀 준비처럼 로딩이 필요한 곳이 [hold]하고, 준비가 끝나면
/// [release]한다. 붙잡은 곳이 없고 앱 첫 프레임이 그려졌으면 걷어낸다. 네이티브는 아무것도
/// 하지 않고 Flutter 로딩 화면(GameLoadingOverlay)을 그대로 쓴다.
abstract final class WebLoadingScreen {
  static int _holds = 0;
  static bool _firstFrame = false;

  /// 웹에서 HTML 로딩 화면이 Flutter 로딩 화면을 대신하는지.
  static bool get replacesFlutterOverlay => kIsWeb;

  static void hold({bool timed = false}) {
    if (!kIsWeb) return;
    _holds += 1;
    showHtmlLoading(timed ? 'gold' : 'teal');
  }

  static void release() {
    if (!kIsWeb) return;
    if (_holds > 0) _holds -= 1;
    _hideIfIdle();
  }

  /// 앱 첫 프레임이 그려진 뒤 한 번 부른다.
  static void markFirstFrame() {
    if (!kIsWeb) return;
    _firstFrame = true;
    _hideIfIdle();
  }

  static void _hideIfIdle() {
    if (_holds == 0 && _firstFrame) hideHtmlLoading();
  }
}
