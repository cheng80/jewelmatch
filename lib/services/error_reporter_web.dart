import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// 창에서 처리되지 않은 JS 오류와 거부된 Promise를 넘긴다. 이름과 스택만 읽는다.
void listenJsErrors(void Function(String? name, String stack) onError) {
  void handle(JSAny? error) {
    try {
      if (error == null || !error.isA<JSObject>()) return;
      final object = error as JSObject;
      final stack = object['stack'];
      if (stack == null || !stack.isA<JSString>()) return;
      final name = object['name'];
      onError(
        name != null && name.isA<JSString>() ? (name as JSString).toDart : null,
        (stack as JSString).toDart,
      );
    } catch (_) {}
  }

  web.window.addEventListener(
    'error',
    ((web.Event e) => handle((e as web.ErrorEvent).error)).toJS,
  );
  web.window.addEventListener(
    'unhandledrejection',
    ((web.Event e) => handle((e as web.PromiseRejectionEvent).reason)).toJS,
  );
}

/// Sentry CLI `sourcemaps inject`가 JS 파일에 심는 전역 `_sentryDebugIds`(스택 문자열 → debug id).
/// 키는 스택 문자열 그대로 넘기고 파일 URL 해석은 호출자가 한다.
Map<String, String> readSentryDebugIds() {
  try {
    final ids = globalContext['_sentryDebugIds'];
    if (ids == null || !ids.isA<JSObject>()) return const {};
    final object = ids as JSObject;
    final keys = (globalContext['Object'] as JSObject)
        .callMethod<JSArray<JSString>>('keys'.toJS, object)
        .toDart;
    return {
      for (final key in keys)
        if (object[key.toDart]?.isA<JSString>() ?? false)
          key.toDart: (object[key.toDart] as JSString).toDart,
    };
  } catch (_) {
    return const {};
  }
}
