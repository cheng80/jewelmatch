import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/resources/native_sfx_slot_pool.dart';
import 'package:stonematch/resources/sound_manager_pitch.dart';

void main() {
  final soundManagerSource = File(
    'lib/resources/sound_manager.dart',
  ).readAsStringSync();
  final webSfxSource = File(
    'lib/resources/sound_manager_web_sfx.dart',
  ).readAsStringSync();
  final webSfxBridgeSource = File(
    'lib/resources/web_sfx_bridge_web.dart',
  ).readAsStringSync();
  final webSfxScript = File('web/stone_match_sfx.js').readAsStringSync();
  final webIndex = File('web/index.html').readAsStringSync();
  final nativeSfxSource = File(
    'lib/resources/sound_manager_native_sfx.dart',
  ).readAsStringSync();
  final vfxSource = File(
    'lib/game/match_board_game_vfx.dart',
  ).readAsStringSync();
  final timingSource = File(
    'lib/game/match_board_game_timing.dart',
  ).readAsStringSync();

  test('보드가 바뀌면 같은 누적 생성 수라도 첫 탄생을 구분한다', () {
    final first = Object();
    final second = Object();
    expect(
      matchSfxTierTracker.read(owner: first, star: 1),
      MatchSfxTier.matchTL,
    );
    expect(
      matchSfxTierTracker.read(owner: second, star: 1),
      MatchSfxTier.matchTL,
    );
    expect(
      matchSfxTierTracker.read(owner: first, star: 1),
      MatchSfxTier.match4,
    );
  });

  test('콤보 단계마다 반음씩 올라가고 상한에서 멈춘다', () {
    expect(SfxPitch.forCombo(0), 0);
    expect(SfxPitch.forCombo(1), 0);
    expect(SfxPitch.forCombo(2), 1);
    expect(SfxPitch.forCombo(9), SfxPitch.maxComboSemitones);
    expect(SfxPitch.forCombo(40), SfxPitch.maxComboSemitones);

    // 반음 = 2^(1/12). 12반음은 정확히 한 옥타브.
    expect(SfxPitch.rateForSemitones(0), 1.0);
    expect(SfxPitch.rateForSemitones(1), closeTo(1.05946, 0.00001));
    expect(SfxPitch.rateForSemitones(12), closeTo(2.0, 0.0001));
    // 상한을 넘겨도 한 옥타브에서 멈춘다.
    expect(SfxPitch.rateForSemitones(99), closeTo(2.0, 0.0001));
  });

  test('매치 크기 등급이 콤보 위에 더해지고 전체 상한을 넘지 않는다', () {
    expect(SfxPitch.forMatch(MatchSfxTier.match4, 1), 0);
    expect(SfxPitch.forMatch(MatchSfxTier.matchTL, 1), 2);
    expect(SfxPitch.forMatch(MatchSfxTier.match5, 1), 3);
    expect(SfxPitch.forMatch(MatchSfxTier.match6plus, 1), 5);
    // 4개 < T/L < 5개 < 6개 이상 순으로 높아진다.
    expect(
      MatchSfxTier.match4.semitones,
      lessThan(MatchSfxTier.matchTL.semitones),
    );
    expect(
      MatchSfxTier.matchTL.semitones,
      lessThan(MatchSfxTier.match5.semitones),
    );
    expect(
      MatchSfxTier.match5.semitones,
      lessThan(MatchSfxTier.match6plus.semitones),
    );

    expect(SfxPitch.forMatch(MatchSfxTier.match6plus, 3), 7);
    expect(
      SfxPitch.forMatch(MatchSfxTier.match6plus, 30),
      SfxPitch.maxSemitones,
    );
  });

  test('저시간 틱은 10초에서 1초로 갈수록 반음씩 오른다', () {
    expect(SfxPitch.forLowTimeTick(10, fromSeconds: 10), 0);
    expect(SfxPitch.forLowTimeTick(9, fromSeconds: 10), 1);
    expect(SfxPitch.forLowTimeTick(1, fromSeconds: 10), 9);
    // 범위 밖 값은 상한과 하한에서 잘린다.
    expect(SfxPitch.forLowTimeTick(30, fromSeconds: 10), 0);
    expect(SfxPitch.forLowTimeTick(-5, fromSeconds: 10), SfxPitch.maxSemitones);
  });

  test('새로 태어난 특수 보석으로 매치 크기 등급을 읽는다', () {
    final tracker = MatchSfxTierTracker();

    expect(tracker.read(), MatchSfxTier.match4);
    expect(tracker.read(star: 1), MatchSfxTier.matchTL);
    expect(tracker.read(star: 1), MatchSfxTier.match4);
    expect(tracker.read(star: 1, hyper: 1), MatchSfxTier.match5);
    expect(
      tracker.read(star: 1, hyper: 1, supernova: 1),
      MatchSfxTier.match6plus,
    );
    // 여러 종류가 한 번에 늘면 큰 쪽을 쓴다.
    expect(
      tracker.read(star: 2, hyper: 2, supernova: 2),
      MatchSfxTier.match6plus,
    );
    // 새 판에서 카운터가 0으로 돌아가도 잘못 올라가지 않는다.
    expect(tracker.read(), MatchSfxTier.match4);
    expect(tracker.read(star: 1), MatchSfxTier.matchTL);
  });

  test('네이티브는 확인 전까지 피치를 무시하는 폴백이고 스위치는 한 곳이다', () {
    expect(SfxPitch.nativePitchEnabled, isFalse);
    expect(SfxPitch.playbackRate(8, isWeb: false), 1.0);
    expect(SfxPitch.playbackRate(8, isWeb: true), greaterThan(1));
    expect(SfxPitch.playbackRate(0, isWeb: true), 1.0);
    expect(nativeSfxSource, contains('SfxPitch.nativePitchEnabled'));
    // 켜면 슬롯 재사용 때 이전 속도가 남지 않도록 매 재생마다 다시 쓴다.
    expect(nativeSfxSource, contains('setPlaybackRate(rate)'));
  });

  test('웹 슬롯은 재생마다 preservesPitch와 playbackRate를 다시 쓴다', () {
    // iOS 15/16은 webkit 접두사만 있어서 셋을 모두 끈다.
    expect(
      webSfxScript,
      contains("'preservesPitch', 'webkitPreservesPitch', 'mozPreservesPitch'"),
    );
    expect(webSfxScript, contains('audio[key] = false;'));
    // 셋 다 없으면 음높이는 그대로인데 속도만 빨라지므로 rate를 1로 둔다.
    expect(webSfxScript, contains('supported && Number.isFinite(rate)'));
    expect(webSfxScript, contains('audio.playbackRate = safe;'));
    expect(
      webSfxScript,
      contains('const appliedRate = applyRate(audio, rate);'),
    );
    // 느리게 재생하면 더 오래 걸리므로 슬롯 반납 타이머도 속도로 나눈다.
    expect(
      webSfxScript,
      contains('Math.max(250, durationMs / appliedRate + 250)'),
    );
    // ADR-004: Web Audio로 돌아가지 않는다.
    expect(webSfxScript, contains('const slotCount = 4;'));
    expect(webSfxScript, isNot(contains('AudioContext')));
  });

  test('의미 → 피치 변환은 SfxPitch 한 곳에서만 한다', () {
    expect(vfxSource, contains('SfxPitch.forMatch(tier, combo)'));
    expect(vfxSource, contains('SfxPitch.forCombo(combo)'));
    expect(vfxSource, contains('matchSfxTierTracker.read('));
    expect(vfxSource, contains('bigMatch || tier != MatchSfxTier.match4'));
    expect(timingSource, contains('SfxPitch.forLowTimeTick('));
    // 호출부는 재생 속도를 직접 계산하지 않는다.
    expect(vfxSource, isNot(contains('playbackRate')));
    expect(timingSource, isNot(contains('playbackRate')));
  });

  test('웹 SFX는 새 AudioPool을 만들지 않고 고정 플레이어 풀을 사용한다', () {
    final poolRoute = soundManagerSource.indexOf(
      'final webPool = kIsWeb ? _webSfxPool : null;',
    );
    final fallbackRoute = soundManagerSource.indexOf(
      'FlameAudio.play(path, volume: vol);',
    );

    expect(poolRoute, isNonNegative);
    expect(soundManagerSource, contains('webPool.play(path, vol, rate);'));
    expect(webSfxSource, contains('playWebSfx(path, volume, duration, rate)'));
    expect(webSfxSource, isNot(contains('AudioPlayer')));
    expect(webSfxBridgeSource, contains("@JS('stoneMatchSfx.play')"));
    expect(webSfxScript, contains('const slotCount = 4;'));
    expect(webSfxScript, contains('new Audio()'));
    expect(webSfxScript, contains('assets/assets/audio/'));
    expect(webSfxScript, isNot(contains('AudioContext')));
    expect(webIndex, contains('<script src="stone_match_sfx.js"></script>'));
    expect(webSfxSource, isNot(contains('FlameAudio.createPool(')));
    expect(fallbackRoute, greaterThan(poolRoute));
  });

  test('웹과 Android만 각자의 SFX 풀을 preload에서 초기화한다', () {
    final unlockPool = soundManagerSource.indexOf('_webSfxPool?.unlock();');
    final skipUnlocked = soundManagerSource.indexOf(
      'if (_webUnlocked) return;',
    );

    expect(soundManagerSource, contains('if (!kIsWeb) return;'));
    expect(unlockPool, isNonNegative);
    expect(skipUnlocked, greaterThan(unlockPool));
    expect(
      soundManagerSource,
      contains('_webSfxPool = await _WebSfxPool.create();'),
    );
    expect(
      soundManagerSource,
      contains(
        '} else if (defaultTargetPlatform == TargetPlatform.android) {\n'
        '      await _initNativeSfxPools();',
      ),
    );
    expect(soundManagerSource, contains('if (kIsWeb) {'));
  });

  test('웹 포커스 복귀 후 다음 입력에서 SFX 풀을 다시 해제한다', () {
    expect(webSfxScript, contains('let needsUnlock = true;'));
    expect(
      webSfxScript,
      contains("document.addEventListener('visibilitychange'"),
    );
    expect(webSfxScript, contains('if (!document.hidden) return;'));
    expect(webSfxScript, contains('if (!needsUnlock) return;'));
    expect(webSfxScript, contains('needsUnlock = false;'));
  });

  test('같은 BGM 재생 요청은 중단된 웹 플레이어를 다시 시작한다', () {
    expect(
      soundManagerSource,
      contains(
        'if (_currentBgm == path) {\n'
        '      if (kIsWeb) {\n'
        '        await playBgmIfUnmuted();\n'
        '      } else {\n'
        '        resumeBgm(onlyIfCurrent: path);\n'
        '      }\n'
        '      return;\n'
        '    }',
      ),
    );
  });

  test('native SFX는 고정 lowLatency 풀을 포화 시 건너뛴다', () {
    expect(
      soundManagerSource,
      contains('final nativePool = _nativeSfxPools[path];'),
    );
    expect(
      soundManagerSource,
      contains('defaultTargetPlatform == TargetPlatform.android'),
    );
    expect(soundManagerSource, contains('await _initNativeSfxPools();'));
    expect(nativeSfxSource, contains('PlayerMode.lowLatency'));
    expect(nativeSfxSource, contains('final slot = _slots.reserve();'));
  });

  test('슬롯은 start 완료 전에도 busy이고 포화 시 예약을 건너뛴다', () async {
    final pool = NativeSfxSlotPool(1);
    final start = Completer<void>();
    final slot = pool.reserve();

    expect(slot, isNotNull);
    unawaited(
      pool.start(
        slot!,
        duration: const Duration(milliseconds: 1),
        onStart: () => start.future,
        onStop: () async {},
      ),
    );

    expect(pool.reserve(), isNull);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(pool.reserve(), isNull);
    start.complete();
  });

  test('stop 완료 후 슬롯을 재사용하고 stale release는 새 세대를 건드리지 않는다', () async {
    final pool = NativeSfxSlotPool(1);
    final stop = Completer<void>();
    final first = pool.reserve()!;

    await pool.start(
      first,
      duration: Duration.zero,
      onStart: () async {},
      onStop: () => stop.future,
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(pool.reserve(), isNull);

    stop.complete();
    await Future<void>.delayed(Duration.zero);
    final second = pool.reserve();
    expect(second, isNotNull);

    pool.release(first);
    expect(pool.reserve(), isNull);

    pool.release(second!);
    expect(pool.reserve(), isNotNull);
  });

  test('start 실패 시 슬롯을 안전하게 해제한다', () async {
    final pool = NativeSfxSlotPool(1);
    final slot = pool.reserve()!;

    await pool.start(
      slot,
      duration: Duration.zero,
      onStart: () async => throw StateError('start failed'),
      onStop: () async {},
    );

    expect(pool.reserve(), isNotNull);
  });
}
