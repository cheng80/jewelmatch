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

/// 브라우저 캐시만 채운다(Dart로 본문을 복사하지 않음).
void warmWebAudio(List<String> paths) {
  try {
    _warm(paths.map((p) => p.toJS).toList().toJS);
  } catch (_) {}
}

bool playWebSfx(String path, double volume, Duration duration, double rate) {
  try {
    return _play(
      path.toJS,
      volume.toJS,
      duration.inMilliseconds.toJS,
      rate.toJS,
    ).toDart;
  } catch (_) {
    return false;
  }
}

@JS('stoneMatchSfx.initialize')
external void _initialize(JSString defaultPath);

@JS('stoneMatchSfx.unlock')
external void _unlock();

@JS('stoneMatchSfx.warm')
external void _warm(JSArray<JSString> paths);

@JS('stoneMatchSfx.play')
external JSBoolean _play(
  JSString path,
  JSNumber volume,
  JSNumber durationMs,
  JSNumber rate,
);
