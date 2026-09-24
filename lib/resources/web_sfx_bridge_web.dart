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

/// 이전 실행(웹 hot restart)이 남긴 재생 중 미디어를 멈춘다. 새로 연 페이지에서는 멈출 것이 없다.
void stopOrphanWebAudio() {
  try {
    _stopOrphans();
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

@JS('stoneMatchSfx.stopOrphans')
external JSNumber _stopOrphans();

@JS('stoneMatchSfx.warm')
external void _warm(JSArray<JSString> paths);

@JS('stoneMatchSfx.play')
external JSBoolean _play(
  JSString path,
  JSNumber volume,
  JSNumber durationMs,
  JSNumber rate,
);
