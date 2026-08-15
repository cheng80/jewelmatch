import 'dart:js_interop';

void initializeWebSfx(String defaultPath) {
  try {
    _initialize(defaultPath.toJS);
  } catch (_) {}
}

void unlockWebSfx() {
  try {
    _unlock();
  } catch (_) {}
}

bool playWebSfx(String path, double volume, Duration duration) {
  try {
    return _play(path.toJS, volume.toJS, duration.inMilliseconds.toJS).toDart;
  } catch (_) {
    return false;
  }
}

@JS('stoneMatchSfx.initialize')
external void _initialize(JSString defaultPath);

@JS('stoneMatchSfx.unlock')
external void _unlock();

@JS('stoneMatchSfx.play')
external JSBoolean _play(JSString path, JSNumber volume, JSNumber durationMs);
