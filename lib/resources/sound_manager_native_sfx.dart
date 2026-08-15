part of 'sound_manager.dart';

Future<void> _initNativeSfxPools() async {
  if (SoundManager._nativeSfxPools.isNotEmpty) return;
  // ponytail: lowLatency has no completion/duration API; update bounds when SFX assets change.
  for (final entry in SoundManager._sfxSpecs.entries) {
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
