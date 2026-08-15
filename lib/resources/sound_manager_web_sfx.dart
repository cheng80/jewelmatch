part of 'sound_manager.dart';

class _WebSfxPool {
  _WebSfxPool._();

  static const _fallbackDuration = Duration(seconds: 5);

  static Future<_WebSfxPool> create() async {
    initializeWebSfx(AssetPaths.sfxCollect);
    return _WebSfxPool._();
  }

  void unlock() => unlockWebSfx();

  void play(String path, double volume) {
    final duration =
        SoundManager._sfxSpecs[path]?.duration ?? _fallbackDuration;
    if (!playWebSfx(path, volume, duration)) {
      SfxPlayLog.append('playSfx web SKIP poolBusy path=$path');
    }
  }
}
