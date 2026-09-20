part of 'sound_manager.dart';

class _WebSfxPool {
  _WebSfxPool._();

  static const _fallbackDuration = Duration(seconds: 5);

  static Future<_WebSfxPool> create() async {
    initializeWebSfx(AssetPaths.sfxCollect);
    return _WebSfxPool._();
  }

  void unlock() => unlockWebSfx();

  void play(String path, double volume, double rate) {
    final duration =
        SoundManager._sfxSpecs[path]?.duration ?? _fallbackDuration;
    if (!playWebSfx(path, volume, duration, rate)) {
      SfxPlayLog.append('playSfx web SKIP poolBusy path=$path');
    }
  }
}
