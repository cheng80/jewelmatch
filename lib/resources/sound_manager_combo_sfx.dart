part of 'sound_manager.dart';

bool _isHigherPriorityThanCombo(String path) {
  return path == AssetPaths.sfxSpecialGem ||
      path == AssetPaths.sfxBigMatch ||
      path == AssetPaths.sfxLevelUp ||
      path == AssetPaths.sfxConfetti ||
      path == AssetPaths.sfxTimeUp;
}

void _cancelPendingComboIfNeeded(String path) {
  if (SoundManager._pendingComboTimer == null) return;
  if (_isHigherPriorityThanCombo(path)) {
    SoundManager._pendingComboTimer?.cancel();
    SoundManager._pendingComboTimer = null;
    SoundManager._pendingComboPath = null;
    SfxPlayLog.append(
      'combo delayed SFX canceled by higher priority path=$path',
    );
  }
}
