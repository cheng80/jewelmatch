part of 'sound_manager.dart';

Future<void> _initNativeSfxPools() async {
  if (SoundManager._nativeSfxPools.isNotEmpty) return;
  // ponytail: lowLatency has no completion/duration API; update bounds when SFX assets change.
  const specs = <String, ({int players, Duration duration})>{
    AssetPaths.sfxBtnSnd: (players: 2, duration: Duration(milliseconds: 250)),
    AssetPaths.sfxCollect: (players: 3, duration: Duration(milliseconds: 1100)),
    AssetPaths.sfxFail: (players: 1, duration: Duration(milliseconds: 1500)),
    AssetPaths.sfxComboHit: (
      players: 3,
      duration: Duration(milliseconds: 1100),
    ),
    AssetPaths.sfxBigMatch: (
      players: 1,
      duration: Duration(milliseconds: 1900),
    ),
    AssetPaths.sfxSpecialGem: (
      players: 1,
      duration: Duration(milliseconds: 1100),
    ),
    AssetPaths.sfxTimeTic: (players: 1, duration: Duration(milliseconds: 600)),
    AssetPaths.sfxTimeUp: (players: 1, duration: Duration(milliseconds: 1700)),
    AssetPaths.sfxStart: (players: 1, duration: Duration(milliseconds: 1100)),
    AssetPaths.sfxClear: (players: 1, duration: Duration(milliseconds: 1000)),
    AssetPaths.sfxLevelUp: (players: 1, duration: Duration(milliseconds: 1300)),
    AssetPaths.sfxConfetti: (
      players: 1,
      duration: Duration(milliseconds: 4400),
    ),
  };
  for (final entry in specs.entries) {
    SoundManager._nativeSfxPools[entry.key] = await _NativeSfxPool.create(
      entry.key,
      playerCount: entry.value.players,
      duration: entry.value.duration,
    );
  }
}

class _NativeSfxPool {
  _NativeSfxPool._(this._duration, this._slots);

  static final _audioContext = AudioContextConfig(
    focus: AudioContextConfigFocus.mixWithOthers,
  ).build();

  final Duration _duration;
  final NativeSfxSlotPool _slots;
  final List<AudioPlayer> _players = [];

  static Future<_NativeSfxPool> create(
    String path, {
    required int playerCount,
    required Duration duration,
  }) async {
    final pool = _NativeSfxPool._(duration, NativeSfxSlotPool(playerCount));
    for (var i = 0; i < playerCount; i++) {
      final player = AudioPlayer()..audioCache = FlameAudio.audioCache;
      await player.setPlayerMode(PlayerMode.lowLatency);
      await player.setAudioContext(_audioContext);
      await player.setSource(AssetSource(path));
      await player.setReleaseMode(ReleaseMode.stop);
      pool._players.add(player);
    }
    return pool;
  }

  void play(double volume) {
    final slot = _slots.reserve();
    if (slot == null) return;
    unawaited(
      _slots.start(
        slot,
        duration: _duration,
        onStart: () async {
          await _players[slot.index].setVolume(volume);
          await _players[slot.index].resume();
        },
        onStop: () => _players[slot.index].stop(),
      ),
    );
  }
}
