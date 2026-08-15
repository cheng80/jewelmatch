part of 'sound_manager.dart';

class _WebSfxPool {
  _WebSfxPool._() : _slots = NativeSfxSlotPool(_playerCount);

  static const _playerCount = 4;
  static const _fallbackDuration = Duration(seconds: 5);

  final NativeSfxSlotPool _slots;
  final List<AudioPlayer> _players = [];
  bool _needsUnlock = true;
  bool _unlockInFlight = false;

  static Future<_WebSfxPool> create() async {
    final pool = _WebSfxPool._();
    for (var i = 0; i < _playerCount; i++) {
      pool._players.add(await _createPlayer());
    }
    return pool;
  }

  static Future<AudioPlayer> _createPlayer() async {
    final player = AudioPlayer()..audioCache = FlameAudio.audioCache;
    await player.setPlayerMode(PlayerMode.mediaPlayer);
    await player.setSource(AssetSource(AssetPaths.sfxCollect));
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setVolume(0);
    return player;
  }

  void unlock() {
    if (!_needsUnlock || _unlockInFlight) return;
    _unlockInFlight = true;
    unawaited(_unlock());
  }

  Future<void> _unlock() async {
    var unlocked = true;
    try {
      await Future.wait(
        List.generate(_players.length, (index) async {
          try {
            await _players[index].resume();
            await _players[index].stop();
          } catch (error, stackTrace) {
            unlocked = false;
            await _replacePlayer(index, error, stackTrace);
          }
        }),
      );
    } finally {
      _needsUnlock = !unlocked;
      _unlockInFlight = false;
    }
  }

  void play(String path, double volume) {
    final slot = _slots.reserve();
    if (slot == null) {
      SfxPlayLog.append('playSfx web SKIP poolBusy path=$path');
      return;
    }
    final duration =
        SoundManager._sfxSpecs[path]?.duration ?? _fallbackDuration;
    final player = _players[slot.index];
    unawaited(
      _slots.start(
        slot,
        duration: duration,
        onStart: () async {
          await player.setVolume(volume);
          await player.setSource(AssetSource(path));
          await player.resume();
        },
        onStop: player.stop,
        onError: (error, stackTrace) =>
            _replacePlayer(slot.index, error, stackTrace),
      ),
    );
  }

  Future<void> _replacePlayer(
    int index,
    Object error,
    StackTrace stackTrace,
  ) async {
    SfxPlayLog.append('playSfx web ERROR slot=$index err=$error');
    _needsUnlock = true;
    try {
      await _players[index].dispose();
      _players[index] = await _createPlayer();
    } catch (replacementError, _) {
      SfxPlayLog.append(
        'playSfx web REPLACE ERROR slot=$index err=$replacementError',
      );
    }
  }
}
