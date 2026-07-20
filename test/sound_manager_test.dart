import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/resources/native_sfx_slot_pool.dart';

void main() {
  final soundManagerSource = File(
    'lib/resources/sound_manager.dart',
  ).readAsStringSync();
  final webSfxSource = File(
    'lib/resources/sound_manager_web_sfx.dart',
  ).readAsStringSync();
  final nativeSfxSource = File(
    'lib/resources/sound_manager_native_sfx.dart',
  ).readAsStringSync();

  test('반복 SFX는 단발 재생 대신 공통 AudioPool을 우선 사용한다', () {
    final poolRoute = soundManagerSource.indexOf(
      'final webPool = kIsWeb ? _webSfxPools[path] : null;',
    );
    final fallbackRoute = soundManagerSource.indexOf(
      'FlameAudio.play(path, volume: vol);',
    );

    expect(poolRoute, isNonNegative);
    expect(
      soundManagerSource,
      contains('unawaited(webPool.start(volume: vol));'),
    );
    expect(fallbackRoute, greaterThan(poolRoute));
  });

  test('웹과 Android만 각자의 SFX 풀을 preload에서 초기화한다', () {
    expect(soundManagerSource, contains('await _initWebSfxPools();'));
    expect(
      soundManagerSource,
      contains(
        '} else if (defaultTargetPlatform == TargetPlatform.android) {\n'
        '      await _initNativeSfxPools();',
      ),
    );
    expect(webSfxSource, contains('if (!kIsWeb ||'));
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
