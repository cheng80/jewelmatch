import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/game/components/bomb_layer_timeline.dart';
import 'package:stonematch/game/components/special_effect_burst.dart';
import 'package:stonematch/game/match_board_logic.dart';

double _scale(Float32List v, BombLayer layer) => v[layer.index * 3];
double _alpha(Float32List v, BombLayer layer) => v[layer.index * 3 + 1];
double _angle(Float32List v, BombLayer layer) => v[layer.index * 3 + 2];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final values = Float32List(bombLayerBufferLength);

  test('버퍼 길이가 레이어 수와 맞는다', () {
    expect(BombLayer.values.length, bombLayerSpriteCount + 1);
    expect(bombLayerBufferLength, BombLayer.values.length * bombLayerStride);
  });

  test('t=0에서는 글로우와 점화만 살아 있고 아직 작다', () {
    evaluateBombLayers(0, values);
    for (final layer in [BombLayer.ring, BombLayer.burst, BombLayer.swirl]) {
      expect(_alpha(values, layer), 0, reason: '$layer');
    }
    expect(_alpha(values, BombLayer.ember), 0);
    // 등장 시점이 t=0인 레이어는 아직 알파가 0이고 바로 다음에 켜진다.
    evaluateBombLayers(0.02, values);
    expect(_alpha(values, BombLayer.ignition), greaterThan(0));
    expect(_alpha(values, BombLayer.glow), greaterThan(0));
    expect(_scale(values, BombLayer.ignition), lessThan(0.7));
  });

  test('정점에서 폭발이 가장 밝고 크기는 계속 자란다', () {
    evaluateBombLayers(0.30, values);
    expect(_alpha(values, BombLayer.burst), closeTo(1.0, 1e-6));
    final peakScale = _scale(values, BombLayer.burst);
    evaluateBombLayers(0.60, values);
    expect(_alpha(values, BombLayer.burst), lessThan(1.0));
    expect(_scale(values, BombLayer.burst), greaterThan(peakScale));
    expect(_alpha(values, BombLayer.ignition), 0, reason: '점화는 이미 끝났다');
  });

  test('회오리와 잔불은 회전하며 늦게 나온다', () {
    evaluateBombLayers(0.20, values);
    expect(_alpha(values, BombLayer.swirl), 0);
    evaluateBombLayers(0.55, values);
    final early = _angle(values, BombLayer.swirl);
    expect(_alpha(values, BombLayer.swirl), greaterThan(0));
    evaluateBombLayers(0.85, values);
    expect(_angle(values, BombLayer.swirl), greaterThan(early));
    expect(_alpha(values, BombLayer.ember), greaterThan(0));
    // 잔불은 커지지 않고 줄어든다.
    final emberEarly = _scale(values, BombLayer.ember);
    evaluateBombLayers(0.95, values);
    expect(_scale(values, BombLayer.ember), lessThan(emberEarly));
  });

  test('t=1에서는 전부 0이고 범위 밖도 마찬가지다', () {
    for (final t in [1.0, 1.5, -0.2]) {
      evaluateBombLayers(t, values);
      for (var i = 0; i < values.length; i++) {
        expect(values[i], 0, reason: 't=$t index=$i');
      }
    }
  });

  test('눈에 보이는 레이어의 최대 배율이 3×3 커버리지 기준에 고정돼 있다', () {
    // 기준 크기 4.5칸 × 티어 × 아래 배율이 화면에 보이는 크기를 정한다(E1 수정 1차).
    var burst = 0.0;
    var swirl = 0.0;
    for (var i = 0; i <= 400; i++) {
      evaluateBombLayers(i / 400, values);
      burst = burst > _scale(values, BombLayer.burst)
          ? burst
          : _scale(values, BombLayer.burst);
      swirl = swirl > _scale(values, BombLayer.swirl)
          ? swirl
          : _scale(values, BombLayer.swirl);
    }
    expect(burst, closeTo(1.20, 0.01));
    expect(swirl, closeTo(1.16, 0.01));
  });

  test('알파는 0~1을 벗어나지 않는다', () {
    for (var i = 0; i <= 200; i++) {
      final t = i / 200;
      evaluateBombLayers(t, values);
      for (final layer in BombLayer.values) {
        expect(_alpha(values, layer), inInclusiveRange(0.0, 1.0));
        expect(_scale(values, layer), inInclusiveRange(0.0, 1.35));
      }
    }
  });

  test('레이어 칸 검증은 같은 정수 정사각형 5칸이 이미지 안에 있기를 요구한다', () {
    List<Rect> row({double cell = 256, double y = 0, int count = 5}) => [
      for (var i = 0; i < count; i++)
        Rect.fromLTWH(i * (cell + 4) + 2, y, cell, cell),
    ];
    bool valid(List<Rect> frames, {double scale = 3.4}) =>
        isValidAreaLayerFrames(
          frames: frames,
          imageWidth: 1320,
          imageHeight: 1044,
          scale: scale,
        );
    expect(valid(row()), isTrue);
    expect(valid(row(cell: 313.5)), isFalse, reason: '비정수 셀은 거부한다');
    expect(valid(row(count: 4)), isFalse, reason: '칸 수가 레이어 수와 달라도 거부한다');
    expect(valid(row(y: 900)), isFalse, reason: '이미지 밖 칸은 거부한다');
    expect(
      valid([...row().take(4), const Rect.fromLTWH(1042, 0, 256, 128)]),
      isFalse,
      reason: '크기가 다른 칸은 거부한다',
    );
    expect(valid(row(y: 0.5)), isFalse, reason: '비정수 좌표는 거부한다');
    expect(valid(row(), scale: 0), isFalse, reason: 'scale이 0이면 거부한다');
    for (final bad in [double.nan, double.infinity]) {
      expect(valid(row(), scale: bad), isFalse);
    }
  });

  test('board_atlas manifest의 범위 효과 칸과 실제 png가 규격을 만족한다', () {
    final manifest =
        jsonDecode(
              File('assets/images/sprites/board_atlas.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final png = File('assets/images/sprites/board_atlas.png').readAsBytesSync();
    final header = ByteData.sublistView(png);
    expect(png.sublist(1, 4), orderedEquals('PNG'.codeUnits));
    final width = header.getUint32(16);
    final height = header.getUint32(20);
    expect(manifest['size'], [width, height]);
    expect(width, lessThanOrEqualTo(2048));
    expect(height, lessThanOrEqualTo(2048));
    final frames = manifest['frames'] as Map<String, dynamic>;
    for (final kind in ['bomb', 'hyper', 'supernova']) {
      final rects = [
        for (var i = 0; i < 5; i++)
          switch (frames['${kind}_$i'] as Map<String, dynamic>) {
            final f => Rect.fromLTWH(
              (f['x'] as num).toDouble(),
              (f['y'] as num).toDouble(),
              (f['w'] as num).toDouble(),
              (f['h'] as num).toDouble(),
            ),
          },
      ];
      expect(
        isValidAreaLayerFrames(
          frames: rects,
          imageWidth: width,
          imageHeight: height,
          scale: 4.5,
        ),
        isTrue,
        reason: kind,
      );
      expect(rects.first.width, 256, reason: '$kind 레이어 칸은 256px');
    }
  });

  test('아틀라스가 없으면 bomb는 기존 절차 경로로 떨어진다', () async {
    expect(SpecialEffectBurst.debugBombLayerAtlasReady, isFalse);
    final burst = SpecialEffectBurst()
      ..activate(
        effectKind: GemKind.bomb,
        origin: Vector2(160, 160),
        affectedCenters: [Vector2(160, 160)],
        tileSize: 40,
        baseColor: Colors.orange,
      );
    burst.onMount();
    burst.update(0.2);
    final recorder = ui.PictureRecorder();
    burst.render(ui.Canvas(recorder));
    final picture = recorder.endRecording();
    final image = await picture.toImage(320, 320);
    final pixels = (await image.toByteData())!;
    var energy = 0;
    for (var i = 0; i < pixels.lengthInBytes; i += 4) {
      energy += pixels.getUint8(i) + pixels.getUint8(i + 1);
    }
    picture.dispose();
    image.dispose();
    burst.onRemove();
    expect(energy, greaterThan(0), reason: 'fallback이 아무것도 안 그리면 안 된다');
  });
}
