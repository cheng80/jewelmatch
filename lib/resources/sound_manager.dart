import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

import '../services/game_settings.dart';
import '../utils/sfx_play_log.dart';
import 'asset_paths.dart';

/// 앱 전역 사운드 관리. BGM·효과음 재생, 볼륨·음소거 적용.
/// 웹: 사용자 상호작용 전까지 자동재생 차단. 첫 탭 시 unlock.
class SoundManager {
  SoundManager._();

  static String? _currentBgm;
  static bool _webUnlocked = false;
  static String? _pendingBgm;
  static Timer? _pendingComboTimer;
  static String? _pendingComboPath;

  /// 웹: 첫 사용자 상호작용 시 호출. 대기 중인 BGM 재생.
  /// playBgm(path) 대신 playBgmIfUnmuted() 사용: 이미 _currentBgm이 설정된 상태에서
  /// playBgm(path)를 호출하면 _currentBgm == path로 early return되어 실제 재생이 안 됨.
  static void unlockForWeb() {
    if (!kIsWeb || _webUnlocked) return;
    _webUnlocked = true;
    if (_pendingBgm != null) {
      _pendingBgm = null;
      playBgmIfUnmuted();
    }
  }

  /// 게임·메뉴 BGM과 효과음을 미리 로드한다. 앱 시작 시 호출.
  static Future<void> preload() async {
    await Future.wait([
      FlameAudio.audioCache.load(AssetPaths.bgmMenu),
      FlameAudio.audioCache.load(AssetPaths.bgmMain),
      FlameAudio.audioCache.load(AssetPaths.sfxTimeTic),
      FlameAudio.audioCache.load(AssetPaths.sfxStart),
      FlameAudio.audioCache.load(AssetPaths.sfxCollect),
      FlameAudio.audioCache.load(AssetPaths.sfxFail),
      FlameAudio.audioCache.load(AssetPaths.sfxClear),
      FlameAudio.audioCache.load(AssetPaths.sfxBtnSnd),
      FlameAudio.audioCache.load(AssetPaths.sfxComboHit),
      FlameAudio.audioCache.load(AssetPaths.sfxBigMatch),
      FlameAudio.audioCache.load(AssetPaths.sfxSpecialGem),
      FlameAudio.audioCache.load(AssetPaths.sfxTimeUp),
    ]);
  }

  static bool _isHigherPriorityThanCombo(String path) {
    return path == AssetPaths.sfxSpecialGem ||
        path == AssetPaths.sfxBigMatch ||
        path == AssetPaths.sfxTimeUp;
  }

  static void _cancelPendingComboIfNeeded(String path) {
    if (_pendingComboTimer == null) return;
    if (_isHigherPriorityThanCombo(path)) {
      _pendingComboTimer?.cancel();
      _pendingComboTimer = null;
      _pendingComboPath = null;
      SfxPlayLog.append('combo delayed SFX canceled by higher priority path=$path');
    }
  }

  /// BGM 재생. 음소거 시에는 _currentBgm만 갱신하고 재생하지 않음.
  /// 웹: unlock 전이면 대기 후 첫 탭 시 재생.
  static Future<void> playBgm(String path) async {
    if (_currentBgm == path) return;
    await stopBgm();
    _currentBgm = path;
    if (GameSettings.bgmMuted) return;
    if (kIsWeb && !_webUnlocked) {
      _pendingBgm = path;
      return;
    }
    try {
      await FlameAudio.bgm.play(path, volume: GameSettings.bgmVolume);
    } catch (_) {
      _pendingBgm = path;
    }
  }

  /// BGM 중지.
  static Future<void> stopBgm() async {
    FlameAudio.bgm.stop();
    _currentBgm = null;
  }

  /// BGM 일시정지. [onlyIfCurrent]가 지정되면 현재 BGM과 일치할 때만 적용.
  static void pauseBgm({String? onlyIfCurrent}) {
    if (onlyIfCurrent != null && _currentBgm != onlyIfCurrent) return;
    FlameAudio.bgm.pause();
  }

  /// BGM 재개. [onlyIfCurrent]가 지정되면 현재 BGM과 일치할 때만 적용.
  static void resumeBgm({String? onlyIfCurrent}) {
    if (onlyIfCurrent != null && _currentBgm != onlyIfCurrent) return;
    if (GameSettings.bgmMuted) return;
    if (_currentBgm == null) return;
    if (FlameAudio.bgm.isPlaying) return;
    if (kIsWeb && !_webUnlocked) return;
    try {
      FlameAudio.bgm.resume();
    } catch (_) {}
  }

  /// 음소거 해제 시 BGM 재생. pause 상태면 resume, stop 상태면 play.
  static Future<void> playBgmIfUnmuted() async {
    if (GameSettings.bgmMuted) return;
    if (_currentBgm == null) return;
    if (FlameAudio.bgm.isPlaying) return;
    if (kIsWeb && !_webUnlocked) return;
    try {
      await FlameAudio.bgm.play(_currentBgm!, volume: GameSettings.bgmVolume);
    } catch (_) {}
  }

  /// BGM 볼륨을 설정에 맞게 적용. 볼륨 슬라이더 변경 시 호출.
  static void applyBgmVolume() {
    if (GameSettings.bgmMuted) return;
    FlameAudio.bgm.audioPlayer.setVolume(GameSettings.bgmVolume);
  }

  /// 효과음 재생. 음소거 시 무시, 볼륨은 GameSettings.sfxVolume 적용.
  /// 웹: unlock 전이면 무시 (카운트다운 등 자동 재생 방지).
  static void playSfx(String path) {
    if (GameSettings.sfxMuted) {
      SfxPlayLog.append('playSfx SKIP sfxMuted path=$path');
      return;
    }
    if (kIsWeb && !_webUnlocked) {
      SfxPlayLog.append('playSfx SKIP webLocked path=$path');
      return;
    }
    _cancelPendingComboIfNeeded(path);
    final vol = GameSettings.sfxVolume;
    SfxPlayLog.append(
      'playSfx ${kIsWeb ? 'web' : 'native'} → path=$path vol=${vol.toStringAsFixed(2)}',
    );
    try {
      FlameAudio.play(path, volume: vol);
    } catch (e, _) {
      SfxPlayLog.append(
        'playSfx ${kIsWeb ? 'web' : 'native'} ERROR path=$path err=$e',
      );
    }
  }

  /// 콤보 강조음은 모바일 웹에서 앞선 SFX와 너무 붙으면 누락될 수 있어
  /// 아주 짧게 지연 후 재생하고, 그 사이 상위 우선순위 SFX가 오면 취소한다.
  static void playComboSfxDelayed(String path) {
    if (GameSettings.sfxMuted) {
      SfxPlayLog.append('playComboSfxDelayed SKIP sfxMuted path=$path');
      return;
    }
    if (kIsWeb && !_webUnlocked) {
      SfxPlayLog.append('playComboSfxDelayed SKIP webLocked path=$path');
      return;
    }
    _pendingComboTimer?.cancel();
    _pendingComboPath = path;
    final delay = kIsWeb
        ? const Duration(milliseconds: 70)
        : const Duration(milliseconds: 40);
    SfxPlayLog.append(
      'playComboSfxDelayed schedule path=$path delayMs=${delay.inMilliseconds}',
    );
    _pendingComboTimer = Timer(delay, () {
      final pending = _pendingComboPath;
      _pendingComboTimer = null;
      _pendingComboPath = null;
      if (pending == null) return;
      playSfx(pending);
    });
  }
}
