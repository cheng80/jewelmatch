import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/game/components/baked_glow_atlas.dart';
import 'package:stonematch/game/components/special_effect_burst.dart';
import 'package:stonematch/game/components/special_effect_pool.dart';
import 'package:stonematch/game/match_board_logic.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final kind in GemKind.values.where((kind) => kind != GemKind.normal)) {
    test('$kind renders baked glow through its procedural path', () async {
      // No onLoad: exercise the real fallback when area sprites are unavailable.
      final burst = _burst(kind, 0);
      final withoutAtlas = await _pixels(burst);
      burst.onMount();
      final withAtlas = await _pixels(burst);
      expect(
        _energy(withAtlas),
        greaterThan(_energy(withoutAtlas)),
        reason: '$kind must actually draw the baked image',
      );
      expect(burst.debugGlowReady, isTrue);
      burst.onRemove();
      expect(burst.debugGlowReady, isFalse);
      burst.onMount();
      expect(await _pixels(burst), orderedEquals(withAtlas));
      burst.onRemove();
    });

    test('$kind tier 2 retains its reduced-detail path', () async {
      final burst = _burst(kind, 2);
      final before = await _pixels(burst);
      burst.onMount();
      final after = await _pixels(burst);
      if (kind == GemKind.hyper) {
        // The existing tier-2 flat radial glow remains visible without blur.
        expect(_energy(after), greaterThan(_energy(before)));
      } else {
        expect(after, orderedEquals(before));
      }
      burst.onRemove();
    });
  }

  test(
    'shared atlas survives another owner removal and supports remount',
    () async {
      final a = BakedGlowAtlas()..mount();
      final b = BakedGlowAtlas()..mount();
      a.mount(); // An owner can only acquire one lease.
      a.dispose();
      a.dispose();
      Future<Uint8List> renderB() => _record((canvas) {
        b.draw(
          canvas,
          GlowShape.star,
          const Offset(160, 160),
          1,
          1,
          Colors.cyan,
        );
      });
      final before = await renderB();
      expect(_energy(before), greaterThan(0));
      b.dispose();
      b.mount();
      expect(await renderB(), orderedEquals(before));
      b.dispose();
    },
  );

  test('pool return retains atlas until component removal', () async {
    final parent = Component();
    final pool = SpecialEffectPool(parent, constrainedDevice: false);
    void spawn() => pool.spawn(
      effectKind: GemKind.star,
      origin: Vector2.all(160),
      affectedCenters: [Vector2(32, 160), Vector2(288, 160)],
      tileSize: 48,
      baseColor: Colors.blue,
    );
    spawn();
    final first = parent.children.whereType<SpecialEffectBurst>().single;
    first.onMount();
    final before = await _pixels(first);
    first.update(1);
    expect(pool.cachedCount, 1);
    expect(first.debugGlowReady, isTrue);
    spawn();
    expect(parent.children.whereType<SpecialEffectBurst>().single, same(first));
    expect(await _pixels(first), orderedEquals(before));
    pool.clear();
    first.onRemove();
    expect(first.debugGlowReady, isFalse);
    expect(pool.activeCount, 0);
    expect(pool.cachedCount, 0);
  });
}

SpecialEffectBurst _burst(GemKind kind, int tier) => SpecialEffectBurst()
  ..activate(
    effectKind: kind,
    origin: Vector2.all(160),
    affectedCenters: [
      Vector2(32, 160),
      Vector2(288, 160),
      Vector2(160, 32),
      Vector2(160, 288),
    ],
    tileSize: 48,
    baseColor: Colors.blue,
    performanceTier: tier,
  )
  ..update(0.12);

Future<Uint8List> _pixels(SpecialEffectBurst burst) => _record(burst.render);

Future<Uint8List> _record(void Function(ui.Canvas) render) async {
  final recorder = ui.PictureRecorder();
  render(ui.Canvas(recorder));
  final picture = recorder.endRecording();
  final image = await picture.toImage(320, 320);
  final bytes = (await image.toByteData())!.buffer.asUint8List();
  image.dispose();
  picture.dispose();
  return bytes;
}

int _energy(Uint8List pixels) =>
    pixels.fold(0, (sum, channel) => sum + channel);
