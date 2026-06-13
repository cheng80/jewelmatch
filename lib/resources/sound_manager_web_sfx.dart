part of 'sound_manager.dart';

Future<void> _initWebSfxPools() async {
  if (SoundManager._webSfxPools.isNotEmpty) return;
  SoundManager._webSfxPools[AssetPaths.sfxBtnSnd] = await FlameAudio.createPool(
    AssetPaths.sfxBtnSnd,
    minPlayers: 1,
    maxPlayers: 2,
  );
  SoundManager._webSfxPools[AssetPaths.sfxCollect] =
      await FlameAudio.createPool(
        AssetPaths.sfxCollect,
        minPlayers: 1,
        maxPlayers: 3,
      );
  SoundManager._webSfxPools[AssetPaths.sfxFail] = await FlameAudio.createPool(
    AssetPaths.sfxFail,
    minPlayers: 1,
    maxPlayers: 1,
  );
  SoundManager._webSfxPools[AssetPaths.sfxComboHit] =
      await FlameAudio.createPool(
        AssetPaths.sfxComboHit,
        minPlayers: 1,
        maxPlayers: 3,
      );
  SoundManager._webSfxPools[AssetPaths.sfxBigMatch] =
      await FlameAudio.createPool(
        AssetPaths.sfxBigMatch,
        minPlayers: 1,
        maxPlayers: 1,
      );
  SoundManager._webSfxPools[AssetPaths.sfxSpecialGem] =
      await FlameAudio.createPool(
        AssetPaths.sfxSpecialGem,
        minPlayers: 1,
        maxPlayers: 1,
      );
  SoundManager._webSfxPools[AssetPaths.sfxTimeTic] =
      await FlameAudio.createPool(
        AssetPaths.sfxTimeTic,
        minPlayers: 1,
        maxPlayers: 1,
      );
  SoundManager._webSfxPools[AssetPaths.sfxTimeUp] = await FlameAudio.createPool(
    AssetPaths.sfxTimeUp,
    minPlayers: 1,
    maxPlayers: 1,
  );
  SoundManager._webSfxPools[AssetPaths.sfxStart] = await FlameAudio.createPool(
    AssetPaths.sfxStart,
    minPlayers: 1,
    maxPlayers: 1,
  );
  SoundManager._webSfxPools[AssetPaths.sfxClear] = await FlameAudio.createPool(
    AssetPaths.sfxClear,
    minPlayers: 1,
    maxPlayers: 1,
  );
  SoundManager._webSfxPools[AssetPaths.sfxLevelUp] =
      await FlameAudio.createPool(
        AssetPaths.sfxLevelUp,
        minPlayers: 1,
        maxPlayers: 1,
      );
  SoundManager._webSfxPools[AssetPaths.sfxConfetti] =
      await FlameAudio.createPool(
        AssetPaths.sfxConfetti,
        minPlayers: 1,
        maxPlayers: 1,
      );
}

void _scheduleWebSfxPrime() {
  if (!kIsWeb ||
      SoundManager._webSfxPools.isEmpty ||
      SoundManager._webPrimeInFlight ||
      SoundManager._webPrimeTimer != null) {
    return;
  }
  SoundManager._webPrimeTimer = Timer(const Duration(milliseconds: 650), () {
    SoundManager._webPrimeTimer = null;
    unawaited(_primeWebSfxPools());
  });
}

Future<void> _primeWebSfxPools() async {
  if (!kIsWeb ||
      SoundManager._webSfxPools.isEmpty ||
      SoundManager._webPrimeInFlight) {
    return;
  }
  final now = DateTime.now();
  if (SoundManager._lastWebPrimeAt != null &&
      now.difference(SoundManager._lastWebPrimeAt!) <
          const Duration(milliseconds: 300)) {
    return;
  }
  SoundManager._webPrimeInFlight = true;
  SoundManager._lastWebPrimeAt = now;
  try {
    for (final entry in SoundManager._webSfxPools.entries) {
      try {
        final stop = await entry.value.start(volume: 0);
        await stop();
      } catch (e, _) {
        SfxPlayLog.append('primeWebSfxPool ERROR path=${entry.key} err=$e');
      }
    }
  } finally {
    SoundManager._webPrimeInFlight = false;
  }
}
