import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

import '../services/game_settings.dart';
import '../utils/sfx_play_log.dart';
import 'asset_paths.dart';
import 'native_sfx_slot_pool.dart';
import 'sound_manager_pitch.dart';
import 'web_sfx_bridge.dart';

export 'sound_manager_pitch.dart';

part 'sound_manager_combo_sfx.dart';
part 'sound_manager_native_sfx.dart';
part 'sound_manager_web_sfx.dart';

/// 앱 전역 사운드 관리. BGM·효과음 재생, 볼륨·음소거 적용.
/// 웹: 사용자 상호작용 전까지 자동재생 차단. 필요한 첫 탭에서 unlock.
class SoundManager {
  SoundManager._();

  static String? _currentBgm;
  static bool _webUnlocked = false;
  static String? _pendingBgm;
  static Timer? _pendingComboTimer;
  static String? _pendingComboPath;
  static int _pendingComboPitch = 0;
  static _WebSfxPool? _webSfxPool;
  static final Map<String, _NativeSfxPool> _nativeSfxPools = {};
  static Future<void>? _preloadFuture;

  static const Map<String, ({int players, Duration duration})> _sfxSpecs = {
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

  /// 웹: 앱 시작 때 호출. hot restart는 Dart만 다시 시작해 이전 실행의 BGM이 계속 울리므로 멈춘다.
  /// 새로 연 페이지에서는 멈출 것이 없어 아무 일도 하지 않는다.
  static void stopOrphansFromPreviousRun() {
    if (!kIsWeb) return;
    stopOrphanWebAudio();
  }

  /// 웹: 사용자 상호작용 시 호출. 대기 중인 BGM 재생.
  /// SFX 풀은 첫 상호작용과 화면 복귀 후 첫 상호작용에서 해제한다.
  static void unlockForWeb() {
    if (!kIsWeb) return;
    _webSfxPool?.unlock();
    if (_webUnlocked) return;
    _webUnlocked = true;
    if (_pendingBgm != null) {
      _pendingBgm = null;
      unawaited(playBgmIfUnmuted());
      return;
    }
    if (_currentBgm != null &&
        !FlameAudio.bgm.isPlaying &&
        !GameSettings.bgmMuted) {
      unawaited(playBgmIfUnmuted());
    }
  }

  /// 게임·메뉴 BGM과 효과음을 미리 로드한다. 앱 시작 시 호출.
  static Future<void> preload() async {
    final existing = _preloadFuture;
    if (existing != null) return existing;
    return _preloadFuture = _preload();
  }

  static Future<void> _preload() async {
    if (kIsWeb) {
      // audioplayers의 웹 AudioCache.load는 브라우저 캐시를 채우려고 http.get으로 파일 전체를
      // Dart 메모리로 읽고 버린다(BGM 5.6MB 포함, 로딩 화면 중 메인 스레드 약 140ms).
      // 주소만 캐시 목록에 등록해 재생 때도 다시 받지 않게 하고, 캐시 채우기는 브라우저 fetch에 맡긴다.
      final cache = FlameAudio.audioCache;
      for (final path in _webAudioWarmOrder) {
        cache.loadedFiles[path] ??= Uri.parse(
          Uri.encodeFull('assets/${cache.prefix}$path'),
        );
      }
      _webSfxPool = await _WebSfxPool.create();
      warmWebAudio(_webAudioWarmOrder);
      return;
    }
    await Future.wait([
      FlameAudio.audioCache.load(AssetPaths.bgmMenu),
      FlameAudio.audioCache.load(AssetPaths.bgmMain),
      FlameAudio.audioCache.load(AssetPaths.sfxTimeTic),
      FlameAudio.audioCache.load(AssetPaths.sfxStart),
      FlameAudio.audioCache.load(AssetPaths.sfxCollect),
      FlameAudio.audioCache.load(AssetPaths.sfxFail),
      FlameAudio.audioCache.load(AssetPaths.sfxClear),
      FlameAudio.audioCache.load(AssetPaths.sfxLevelUp),
      FlameAudio.audioCache.load(AssetPaths.sfxConfetti),
      FlameAudio.audioCache.load(AssetPaths.sfxBtnSnd),
      FlameAudio.audioCache.load(AssetPaths.sfxComboHit),
      FlameAudio.audioCache.load(AssetPaths.sfxBigMatch),
      FlameAudio.audioCache.load(AssetPaths.sfxSpecialGem),
      FlameAudio.audioCache.load(AssetPaths.sfxTimeUp),
    ]);
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _initNativeSfxPools();
    }
  }

  /// 웹 캐시 채우기 순서. 게임에서 먼저 쓰는 효과음, 게임 BGM, 메뉴 BGM 순이다.
  static const List<String> _webAudioWarmOrder = [
    AssetPaths.sfxStart,
    AssetPaths.sfxCollect,
    AssetPaths.sfxComboHit,
    AssetPaths.sfxBigMatch,
    AssetPaths.sfxSpecialGem,
    AssetPaths.sfxBtnSnd,
    AssetPaths.sfxTimeTic,
    AssetPaths.sfxFail,
    AssetPaths.sfxTimeUp,
    AssetPaths.sfxClear,
    AssetPaths.sfxLevelUp,
    AssetPaths.sfxConfetti,
    AssetPaths.bgmMain,
    AssetPaths.bgmMenu,
  ];

  /// BGM 재생. 음소거 시에는 _currentBgm만 갱신하고 재생하지 않음.
  /// 웹: unlock 전이면 대기 후 첫 탭 시 재생.
  static Future<void> playBgm(String path) async {
    if (_currentBgm == path) {
      if (kIsWeb) {
        await playBgmIfUnmuted();
      } else {
        resumeBgm(onlyIfCurrent: path);
      }
      return;
    }
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

  /// 음소거 해제나 웹 플레이어 중단 후 BGM을 다시 재생.
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

  /// 반음 → 재생 속도. 네이티브는 피치까지 바뀌는지 확인 전까지 1.0으로 고정한다
  /// (속도만 빨라지면 어색하다). 켜는 스위치는 `SfxPitch.nativePitchEnabled` 한 곳.
  static double _playbackRate(int pitchSemitones) {
    return SfxPitch.playbackRate(pitchSemitones, isWeb: kIsWeb);
  }

  /// 효과음 재생. 음소거 시 무시, 볼륨은 GameSettings.sfxVolume 적용.
  /// 웹: unlock 전이면 무시 (카운트다운 등 자동 재생 방지).
  /// [pitchSemitones]는 반음 단위 피치 상승. 의미 → 반음 변환은 `SfxPitch`에 있다.
  static void playSfx(String path, {int pitchSemitones = 0}) {
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
    final rate = _playbackRate(pitchSemitones);
    final webPool = kIsWeb ? _webSfxPool : null;
    // preload 전 웹 폴백은 FlameAudio로 빠져 rate를 버린다. 로그도 실제 재생과 맞춘다.
    final loggedRate = kIsWeb && webPool == null ? 1.0 : rate;
    SfxPlayLog.append(
      'playSfx ${kIsWeb ? 'web' : 'native'} → path=$path vol=${vol.toStringAsFixed(2)} rate=${loggedRate.toStringAsFixed(3)}',
    );
    try {
      if (webPool != null) {
        webPool.play(path, vol, rate);
        return;
      }
      if (defaultTargetPlatform == TargetPlatform.android) {
        final nativePool = _nativeSfxPools[path];
        if (nativePool != null) {
          nativePool.play(vol, rate);
          return;
        }
      }
      FlameAudio.play(path, volume: vol);
    } catch (e, _) {
      SfxPlayLog.append(
        'playSfx ${kIsWeb ? 'web' : 'native'} ERROR path=$path err=$e',
      );
    }
  }

  /// 콤보 강조음은 모바일 웹에서 앞선 SFX와 너무 붙으면 누락될 수 있어
  /// 아주 짧게 지연 후 재생하고, 그 사이 상위 우선순위 SFX가 오면 취소한다.
  static void playComboSfxDelayed(String path, {int pitchSemitones = 0}) {
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
    _pendingComboPitch = pitchSemitones;
    final delay = kIsWeb
        ? const Duration(milliseconds: 70)
        : const Duration(milliseconds: 40);
    SfxPlayLog.append(
      'playComboSfxDelayed schedule path=$path delayMs=${delay.inMilliseconds}',
    );
    _pendingComboTimer = Timer(delay, () {
      final pending = _pendingComboPath;
      final pitch = _pendingComboPitch;
      _pendingComboTimer = null;
      _pendingComboPath = null;
      _pendingComboPitch = 0;
      if (pending == null) return;
      playSfx(pending, pitchSemitones: pitch);
    });
  }
}
