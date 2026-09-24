import 'dart:js_interop';

@JS('stoneMatchLoading.show')
external void _show(JSString accent);

@JS('stoneMatchLoading.hide')
external void _hide();

void showHtmlLoading(String accent) {
  try {
    _show(accent.toJS);
  } catch (_) {}
}

void hideHtmlLoading() {
  try {
    _hide();
  } catch (_) {}
}
