import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../resources/sound_manager.dart';
import '../services/game_settings.dart';

/// 오디오·화면 설정 상태. SettingView와 PauseMenuOverlay가 공유한다.
class SettingsState {
  const SettingsState({
    this.bgmVolume = 0.5,
    this.sfxVolume = 1.0,
    this.bgmMuted = false,
    this.sfxMuted = false,
    this.keepScreenOn = true,
  });

  final double bgmVolume;
  final double sfxVolume;
  final bool bgmMuted;
  final bool sfxMuted;
  final bool keepScreenOn;

  SettingsState copyWith({
    double? bgmVolume,
    double? sfxVolume,
    bool? bgmMuted,
    bool? sfxMuted,
    bool? keepScreenOn,
  }) {
    return SettingsState(
      bgmVolume: bgmVolume ?? this.bgmVolume,
      sfxVolume: sfxVolume ?? this.sfxVolume,
      bgmMuted: bgmMuted ?? this.bgmMuted,
      sfxMuted: sfxMuted ?? this.sfxMuted,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
    );
  }
}

/// 설정 읽기/쓰기 + SoundManager·WakelockPlus 적용을 담당하는 Notifier.
class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    return SettingsState(
      bgmVolume: GameSettings.bgmVolume,
      sfxVolume: GameSettings.sfxVolume,
      bgmMuted: GameSettings.bgmMuted,
      sfxMuted: GameSettings.sfxMuted,
      keepScreenOn: GameSettings.keepScreenOn,
    );
  }

  void setBgmVolumeDraft(double v) {
    if (state.bgmVolume == v) return;
    state = state.copyWith(bgmVolume: v);
    if (!state.bgmMuted) {
      SoundManager.applyBgmVolume();
    }
  }

  void commitBgmVolume() {
    GameSettings.bgmVolume = state.bgmVolume;
    if (!state.bgmMuted) {
      SoundManager.applyBgmVolume();
    }
  }

  void setSfxVolumeDraft(double v) {
    if (state.sfxVolume == v) return;
    state = state.copyWith(sfxVolume: v);
  }

  void commitSfxVolume() {
    GameSettings.sfxVolume = state.sfxVolume;
  }

  void setBgmMuted(bool v) {
    if (state.bgmMuted == v) return;
    GameSettings.bgmMuted = v;
    if (v) {
      SoundManager.pauseBgm();
    } else {
      SoundManager.playBgmIfUnmuted();
    }
    state = state.copyWith(bgmMuted: v);
  }

  void setSfxMuted(bool v) {
    if (state.sfxMuted == v) return;
    GameSettings.sfxMuted = v;
    state = state.copyWith(sfxMuted: v);
  }

  void setKeepScreenOn(bool v) {
    if (state.keepScreenOn == v) return;
    GameSettings.keepScreenOn = v;
    if (v) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
    state = state.copyWith(keepScreenOn: v);
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
