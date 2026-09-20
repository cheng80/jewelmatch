import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/game/components/area_layer_timeline.dart';
import 'package:stonematch/game/components/bomb_layer_timeline.dart';
import 'package:stonematch/game/components/special_effect_burst.dart';
import 'package:stonematch/game/components/special_effect_pool.dart';
import 'package:stonematch/game/match_board_logic.dart';

const _kinds = [GemKind.bomb, GemKind.hyper, GemKind.supernova];
const _side = 512;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<void> restore() => SpecialEffectBurst.debugReloadAreaEffectSprites(
    bundle: rootBundle,
    loadImage: Flame.images.load,
  );

  test(
    'preload and pool warm load all three independent layer atlases',
    () async {
      await SpecialEffectBurst.preloadAreaEffectSprites();
      for (final kind in _kinds) {
        expect(SpecialEffectBurst.debugLayerAtlasReady(kind), isTrue);
      }
      final parent = Component();
      await parent.onLoad();
      final pool = SpecialEffectPool(parent, constrainedDevice: true);
      await pool.warm(burstCount: 1);
      final instance = parent.children.whereType<SpecialEffectBurst>().single;
      instance.onMount();
      for (final kind in [
        GemKind.hyper,
        GemKind.supernova,
        GemKind.bomb,
        GemKind.hyper,
      ]) {
        pool.spawn(
          effectKind: kind,
          origin: Vector2.all(256),
          affectedCenters: const [],
          tileSize: 48,
          baseColor: Colors.blue,
        );
        expect(
          parent.children.whereType<SpecialEffectBurst>().single,
          same(instance),
        );
        expect(instance.performanceTier, kind == GemKind.bomb ? 1 : 2);
        instance.update(0.15);
        final reused = await _pixels(instance);
        final fresh = _burst(kind, instance.performanceTier)..update(0.15);
        fresh.onMount();
        expect(
          reused,
          orderedEquals(await _pixels(fresh)),
          reason: 'no stale kind, elapsed or atlas rects',
        );
        fresh.onRemove();
        instance.update(1);
        expect(_energy(await _pixels(instance)), 0);
        expect(pool.cachedCount, 1);
        expect(instance.debugGlowReady, isTrue);
      }
      pool.clear();
      instance.onRemove();
      expect(instance.debugGlowReady, isFalse);
      // Component removal releases only its glow lease, not Flame-owned assets.
      await restore();
      for (final kind in _kinds) {
        expect(SpecialEffectBurst.debugLayerAtlasReady(kind), isTrue);
      }
    },
  );

  test(
    'atlas kind isolation and fixed 128px pivot through growth and rotation',
    () async {
      final images = <GemKind, ui.Image>{};
      for (final kind in _kinds) {
        images[kind] = _synthetic(switch (kind) {
          GemKind.bomb => const Color(0xFFFF0000),
          GemKind.hyper => const Color(0xFF00FF00),
          _ => const Color(0xFF0000FF),
        });
      }
      try {
        await _load(
          _manifest(),
          (path) async => images[_kinds.firstWhere((k) => path == k.name)]!,
        );
        for (final kind in _kinds) {
          for (final t in [0.04, 0.22, 0.55, 0.82]) {
            final burst = _burst(kind, 2)..update(_life(kind) * t);
            final pixels = await _pixels(burst);
            final sums = _channels(pixels);
            final channel = _kinds.indexOf(kind);
            expect(sums[channel], greaterThan(0), reason: '$kind t=$t');
            for (var c = 0; c < 3; c++) {
              if (c != channel) {
                expect(
                  sums[c],
                  0,
                  reason: 'loader overwrote $kind with another atlas',
                );
              }
            }
            final b = _bbox(pixels);
            expect(
              (b[0] + b[2]) / 2,
              closeTo(256, 1),
              reason: '$kind t=$t pivot x',
            );
            expect(
              (b[1] + b[3]) / 2,
              closeTo(256, 1),
              reason: '$kind t=$t pivot y',
            );
          }
        }
      } finally {
        await restore();
        for (final image in images.values) {
          image.dispose();
        }
      }
    },
  );

  test(
    'invalid cells/count/size and missing image isolate fallback to that kind',
    () async {
      final valid = _synthetic(Colors.red);
      final wrongSize = _synthetic(Colors.blue, width: 1024);
      try {
        for (final invalid in [
          'fractional-cell',
          'fractional-count',
          'wrong-size',
          'missing',
          'zero-scale',
        ]) {
          final manifest = _manifest();
          final effect =
              (manifest['effects'] as Map<String, dynamic>)['hyper']
                  as Map<String, dynamic>;
          if (invalid == 'fractional-cell') effect['layerCellSize'] = 255.5;
          if (invalid == 'fractional-count') effect['layerCount'] = 5.5;
          if (invalid == 'zero-scale') effect['scale'] = 0;
          await _load(manifest, (path) async {
            if (path == 'hyper') {
              if (invalid == 'missing') throw StateError('missing hyper asset');
              if (invalid == 'wrong-size') return wrongSize;
            }
            return valid;
          });
          expect(SpecialEffectBurst.debugLayerAtlasReady(GemKind.bomb), isTrue);
          expect(
            SpecialEffectBurst.debugLayerAtlasReady(GemKind.hyper),
            isFalse,
            reason: invalid,
          );
          expect(
            SpecialEffectBurst.debugLayerAtlasReady(GemKind.supernova),
            isTrue,
            reason: 'a failed hyper must not abort later entries',
          );
          final burst = _burst(GemKind.hyper, 2)..update(0.12);
          expect(
            _energy(await _pixels(burst)),
            greaterThan(0),
            reason: 'procedural fallback',
          );
        }
        await _load({'effects': {}}, (_) async => valid);
        for (final kind in [GemKind.hyper, GemKind.supernova]) {
          final fallback = _burst(kind, 2)..update(0.12);
          expect(_energy(await _pixels(fallback)), greaterThan(0));
        }
      } finally {
        await restore();
        valid.dispose();
        wrongSize.dispose();
      }
    },
  );

  test(
    'real Flutter start/peak/tail/end, tiers, glow leases and captured frames',
    () async {
      await restore();
      for (final kind in _kinds) {
        for (final tier in [0, 1, 2]) {
          final samples = <double, int>{};
          for (final t in [0.0, 0.06, 0.30, 0.56, 0.78, 1.0]) {
            final burst = _burst(kind, tier)..update(_life(kind) * t);
            burst.onMount();
            final bytes = await _pixels(
              burst,
              capture: '${kind.name}-tier$tier-t${(t * 100).round()}',
            );
            samples[t] = _energy(bytes);
            burst.onRemove();
          }
          expect(samples[0.0], 0);
          expect(samples[0.06], greaterThan(0));
          expect(
            samples[0.30],
            greaterThan(samples[0.78]!),
            reason: '$kind tier=$tier samples=$samples',
          );
          expect(samples[0.78], greaterThan(0));
          expect(samples[1.0], 0, reason: 'no sprite or glow after expiry');
        }
        final energies = <int>[];
        for (final tier in [0, 1, 2]) {
          final burst = _burst(kind, tier)..update(_life(kind) * .30);
          burst.onMount();
          final mounted = await _pixels(burst);
          energies.add(_energy(mounted));
          burst.onRemove();
          final unmounted = await _pixels(burst);
          if (tier < 2) {
            expect(
              _energy(mounted),
              greaterThan(_energy(unmounted)),
              reason: 'actual layer path draws baked glow',
            );
          } else {
            expect(
              mounted,
              orderedEquals(unmounted),
              reason: 'tier 2 glow remains disabled',
            );
          }
          burst.onMount();
          expect(await _pixels(burst), orderedEquals(mounted));
          burst.onRemove();
        }
        expect(energies[0], greaterThan(energies[1]));
        expect(energies[1], greaterThan(energies[2]));
      }
    },
  );

  test(
    'hyper and supernova envelopes are bounded, differentiated and residue barely rotates',
    () {
      final hyper = Float32List(bombLayerBufferLength);
      final nova = Float32List(bombLayerBufferLength);
      for (var i = 0; i <= 200; i++) {
        final t = i / 200;
        evaluateHyperLayers(t, hyper);
        evaluateSupernovaLayers(t, nova);
        for (final values in [hyper, nova]) {
          for (var layer = 0; layer < 6; layer++) {
            expect(values[layer * 3], inInclusiveRange(0, 1.3));
            expect(values[layer * 3 + 1], inInclusiveRange(0, .720001));
          }
          if (i == 0 || i == 200) expect(values, everyElement(0));
        }
        expect(hyper[17].abs(), lessThanOrEqualTo(.081));
        expect(nova[17], 0);
      }
      evaluateHyperLayers(.56, hyper);
      evaluateSupernovaLayers(.56, nova);
      expect(hyper, isNot(orderedEquals(nova)));
      for (final bad in [double.nan, double.infinity]) {
        expect(
          isValidBombLayerAtlas(
            imageWidth: 1280,
            imageHeight: 256,
            cellSize: bad,
            layerCount: 5,
            scale: 4,
          ),
          false,
        );
        expect(
          isValidBombLayerAtlas(
            imageWidth: 1280,
            imageHeight: 256,
            cellSize: 256,
            layerCount: 5,
            scale: bad,
          ),
          false,
        );
      }
    },
  );
}

double _life(GemKind k) => switch (k) {
  GemKind.bomb => .52,
  GemKind.hyper => .60,
  _ => .72,
};
SpecialEffectBurst _burst(GemKind k, int tier) =>
    SpecialEffectBurst()..activate(
      effectKind: k,
      origin: Vector2.all(256),
      affectedCenters: const [],
      tileSize: 48,
      baseColor: Colors.blue,
      performanceTier: tier,
    );

Future<Uint8List> _pixels(SpecialEffectBurst burst, {String? capture}) async {
  final recorder = ui.PictureRecorder();
  burst.render(ui.Canvas(recorder));
  final picture = recorder.endRecording();
  final image = await picture.toImage(_side, _side);
  final result = (await image.toByteData())!.buffer.asUint8List();
  final dir = Platform.environment['E2_CAPTURE_DIR'];
  if (dir != null && capture != null) {
    Directory(dir).createSync(recursive: true);
    // Capture the real plus blend directly over the game-cell background.
    final captureRecorder = ui.PictureRecorder();
    final canvas = ui.Canvas(captureRecorder);
    canvas.drawColor(const Color(0xFF20211E), BlendMode.src);
    burst.render(canvas);
    final capturePicture = captureRecorder.endRecording();
    final captureImage = await capturePicture.toImage(_side, _side);
    File('$dir/$capture.png').writeAsBytesSync(
      (await captureImage.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List(),
    );
    captureImage.dispose();
    capturePicture.dispose();
  }
  image.dispose();
  picture.dispose();
  return result;
}

int _energy(Uint8List bytes) => _channels(bytes).fold(0, (a, b) => a + b);
List<int> _channels(Uint8List bytes) {
  final sums = [0, 0, 0];
  for (var i = 0; i < bytes.length; i += 4) {
    for (var c = 0; c < 3; c++) {
      sums[c] += bytes[i + c];
    }
  }
  return sums;
}

List<int> _bbox(Uint8List p) {
  var x0 = _side, y0 = _side, x1 = 0, y1 = 0;
  for (var y = 0; y < _side; y++) {
    for (var x = 0; x < _side; x++) {
      if (p[(y * _side + x) * 4 + 3] == 0) continue;
      if (x < x0) x0 = x;
      if (y < y0) y0 = y;
      if (x >= x1) x1 = x + 1;
      if (y >= y1) y1 = y + 1;
    }
  }
  return [x0, y0, x1, y1];
}

ui.Image _synthetic(Color color, {int width = 1280}) {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final paint = ui.Paint()..color = color;
  for (var i = 0; i < 5; i++) {
    canvas.drawCircle(Offset(i * 256 + 128, 128), 32, paint);
  }
  final picture = recorder.endRecording();
  final image = picture.toImageSync(width, 256);
  picture.dispose();
  return image;
}

Map<String, dynamic> _manifest() => {
  'effects': {
    for (final k in _kinds)
      k.name: {
        'image': k.name,
        'layerCellSize': 256,
        'layerCount': 5,
        'scale': 4.5,
      },
  },
};
Future<void> _load(
  Map<String, dynamic> manifest,
  Future<ui.Image> Function(String) load,
) => SpecialEffectBurst.debugReloadAreaEffectSprites(
  bundle: _Bundle(manifest),
  loadImage: load,
);

class _Bundle extends CachingAssetBundle {
  _Bundle(this.manifest);
  final Map<String, dynamic> manifest;
  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      jsonEncode(manifest);
  @override
  Future<ByteData> load(String key) => throw UnimplementedError();
}
