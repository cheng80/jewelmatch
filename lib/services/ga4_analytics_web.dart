import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'ga4_analytics.dart';

/// gtag.js를 별도 SDK 없이 직접 붙인다. 처음 쓰일 때(동의 뒤)만 만들어진다.
Ga4Sink createGa4Sink() => _WebSink();

class _WebSink implements Ga4Sink {
  JSFunction? _fn;

  /// 공식 스니펫과 같은 `function gtag(){dataLayer.push(arguments);}`.
  /// gtag.js는 배열이 아니라 arguments 객체를 명령으로 읽으므로 JS 함수로 만든다.
  JSFunction get _gtagFn {
    final existing = _fn;
    if (existing != null) return existing;
    if (globalContext['dataLayer'] == null) {
      globalContext['dataLayer'] = JSArray();
    }
    final fn = (globalContext['Function'] as JSFunction)
        .callAsConstructor<JSFunction>(
          'window.dataLayer.push(arguments);'.toJS,
        );
    globalContext['gtag'] = fn;
    return _fn = fn;
  }

  @override
  Future<bool> load(String measurementId) {
    final done = Completer<bool>();
    try {
      _gtagFn;
      final script = web.HTMLScriptElement()
        ..async = true
        // 응답에 CORP cross-origin과 ACAO *가 있어 COEP require-corp에서도 CORS 모드로 받을 수 있다.
        ..crossOrigin = 'anonymous'
        ..src =
            'https://www.googletagmanager.com/gtag/js?id=${Uri.encodeQueryComponent(measurementId)}';
      script.onload = ((web.Event _) {
        if (!done.isCompleted) done.complete(true);
      }).toJS;
      script.onerror = ((web.Event _) {
        if (!done.isCompleted) done.complete(false);
      }).toJS;
      web.document.head!.append(script);
    } catch (_) {
      if (!done.isCompleted) done.complete(false);
    }
    return done.future;
  }

  @override
  void gtag(String command, String target, [Map<String, Object?>? params]) {
    try {
      final JSAny second = command == 'js'
          ? (globalContext['Date'] as JSFunction).callAsConstructor<JSObject>()
          : target.toJS;
      if (params == null) {
        _gtagFn.callAsFunction(null, command.toJS, second);
      } else {
        _gtagFn.callAsFunction(null, command.toJS, second, params.jsify());
      }
    } catch (_) {}
  }

  @override
  void setDisabled(String measurementId, bool disabled) {
    try {
      globalContext['ga-disable-$measurementId'] = disabled.toJS;
    } catch (_) {}
  }

  @override
  String get referrer {
    try {
      return web.document.referrer;
    } catch (_) {
      return '';
    }
  }

  /// 이 게임이 생성한 host-only /match/ 쿠키만 만료시킨다.
  @override
  void clearCookies(String measurementId) {
    try {
      final names = [
        'sm_ga',
        'sm_ga_${measurementId.startsWith('G-') ? measurementId.substring(2) : measurementId}',
      ];
      for (final name in names) {
        web.document.cookie =
            '$name=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/match/';
      }
    } catch (_) {}
  }
}
