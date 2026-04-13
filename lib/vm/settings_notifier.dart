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

  void setBgmVolume(double v) {
    GameSettings.bgmVolume = v;
    SoundManager.applyBgmVolume();
    state = state.copyWith(bgmVolume: v);
  }

  void setSfxVolume(double v) {
    GameSettings.sfxVolume = v;
    state = state.copyWith(sfxVolume: v);
  }

  void setBgmMuted(bool v) {
    GameSettings.bgmMuted = v;
    if (v) {
      SoundManager.pauseBgm();
    } else {
      SoundManager.playBgmIfUnmuted();
    }
    state = state.copyWith(bgmMuted: v);
  }

  void setSfxMuted(bool v) {
    GameSettings.sfxMuted = v;
    state = state.copyWith(sfxMuted: v);
  }

  void setKeepScreenOn(bool v) {
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
