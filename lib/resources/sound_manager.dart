import 'dart:async' show unawaited;

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

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

  /// 웹 전용 효과음 [AudioPlayer] 풀.
  ///
  /// - 플레이어 1개만 쓰면 연속 `play()`에 앞선 음이 끊긴다(크롬에서 특히 체감).
  /// - 풀을 너무 크게 잡으면 iOS Safari에서 동시 `<audio>` 제한으로 `NotAllowedError`가 난다.
  /// - [playSfx]→[play] 호출은 **await 없이** 이어지도록 해 WebKit의 사용자 제스처 정책에 맞춘다.
  static const int _webSfxPoolSize = 3;
  static List<AudioPlayer>? _webSfxPool;
  static int _webSfxPoolIndex = 0;
  static Future<void>? _webSfxPoolReady;

  /// 웹: 첫 사용자 상호작용 시 호출. 대기 중인 BGM 재생.
  /// playBgm(path) 대신 playBgmIfUnmuted() 사용: 이미 _currentBgm이 설정된 상태에서
  /// playBgm(path)를 호출하면 _currentBgm == path로 early return되어 실제 재생이 안 됨.
  ///
  /// 포인터다운마다 호출되며, 웹 효과음용 플레이어 풀([_ensureWebSfxPool])을 한 번만 채운다.
  static void unlockForWeb() {
    if (!kIsWeb) return;
    _primeWebAudioSync();
    if (!_webUnlocked) {
      _webUnlocked = true;
      if (_pendingBgm != null) {
        _pendingBgm = null;
        playBgmIfUnmuted();
      }
    }
    unawaited(_ensureWebSfxPool());
  }

  static Future<void> _ensureWebSfxPool() async {
    if (_webSfxPool != null && _webSfxPool!.length == _webSfxPoolSize) {
      return;
    }
    if (_webSfxPoolReady != null) {
      await _webSfxPoolReady;
      return;
    }
    _webSfxPoolReady = () async {
      final ctx = AudioContextConfig(
        focus: AudioContextConfigFocus.mixWithOthers,
      ).build();
      final pool = <AudioPlayer>[];
      for (var i = 0; i < _webSfxPoolSize; i++) {
        final p = AudioPlayer()..audioCache = FlameAudio.audioCache;
        await p.setReleaseMode(ReleaseMode.release);
        await p.setPlayerMode(PlayerMode.mediaPlayer);
        await p.setAudioContext(ctx);
        pool.add(p);
      }
      _webSfxPool = pool;
    }();
    await _webSfxPoolReady;
  }

  /// 웹 첫 제스처에서 이미 준비된 플레이어로 0볼륨 SFX를 한 번 흘려
  /// 브라우저 자동재생 잠금을 푸는 시도.
  ///
  /// 핵심은 `play()` 호출이 사용자 제스처와 같은 동기 스택에서 시작되는 것이다.
  static void _primeWebAudioSync() {
    final pool = _webSfxPool;
    if (pool != null && pool.length == _webSfxPoolSize) {
      final i = _webSfxPoolIndex % pool.length;
      _webSfxPoolIndex++;
      unawaited(
        pool[i].play(AssetSource(AssetPaths.sfxBtnSnd), volume: 0).catchError((
          Object e,
          StackTrace _,
        ) {
          SfxPlayLog.append('web unlock prime ERROR err=$e');
        }),
      );
      return;
    }
    unawaited(
      _ensureWebSfxPool().then((_) {
        final readyPool = _webSfxPool;
        if (readyPool == null || readyPool.isEmpty) return null;
        final i = _webSfxPoolIndex % readyPool.length;
        _webSfxPoolIndex++;
        return readyPool[i]
            .play(AssetSource(AssetPaths.sfxBtnSnd), volume: 0)
            .catchError((Object e, StackTrace _) {
              SfxPlayLog.append('web unlock ensure ERROR err=$e');
            });
      }),
    );
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
    if (kIsWeb) {
      await _ensureWebSfxPool();
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
  ///
  /// 웹에서는 [FlameAudio.play] 기본값인 `PlayerMode.lowLatency`(Web Audio)가
  /// 특정 MP3 인코딩에서만 재생 실패하는 경우가 있어, 효과음은 `mediaPlayer` 모드로 통일한다.
  static void playSfx(String path) {
    if (GameSettings.sfxMuted) {
      SfxPlayLog.append('playSfx SKIP sfxMuted path=$path');
      return;
    }
    if (kIsWeb && !_webUnlocked) {
      SfxPlayLog.append('playSfx SKIP webLocked path=$path');
      return;
    }
    final vol = GameSettings.sfxVolume;
    if (kIsWeb) {
      SfxPlayLog.append('playSfx web → path=$path vol=${vol.toStringAsFixed(2)}');
      _playSfxWeb(path, vol);
      return;
    }
    SfxPlayLog.append('playSfx native → path=$path vol=${vol.toStringAsFixed(2)}');
    try {
      FlameAudio.play(path, volume: vol);
    } catch (e, _) {
      SfxPlayLog.append('playSfx native ERROR path=$path err=$e');
    }
  }

  /// WebKit(Safari): `play()`가 포인터 핸들러와 **같은 동기 스택**에서 시작돼야
  /// `NotAllowedError`를 피하는 경우가 많다. 풀이 이미 있으면 `await` 없이 곧바로
  /// [AudioPlayer.play]를 호출한다.
  static void _playSfxWeb(String path, double volume) {
    if (_webSfxPool != null && _webSfxPool!.length == _webSfxPoolSize) {
      _fireWebPoolPlay(path, volume);
      return;
    }
    unawaited(_ensureWebSfxPool().then((_) {
      _fireWebPoolPlay(path, volume);
    }).catchError((Object e, StackTrace _) {
      SfxPlayLog.append('playSfx web ensure ERROR path=$path err=$e');
    }));
  }

  static void _fireWebPoolPlay(String path, double volume) {
    final pool = _webSfxPool;
    if (pool == null || pool.isEmpty) {
      SfxPlayLog.append('playSfx web ERROR empty pool path=$path');
      return;
    }
    final i = _webSfxPoolIndex % pool.length;
    _webSfxPoolIndex++;
    SfxPlayLog.append('playSfx web pool[$i] play start path=$path');
    unawaited(
      pool[i].play(AssetSource(path), volume: volume).then((_) {
        SfxPlayLog.append('playSfx web pool[$i] play completed path=$path');
      }).catchError((Object e, StackTrace _) {
        SfxPlayLog.append('playSfx web ERROR path=$path err=$e');
      }),
    );
  }
}
