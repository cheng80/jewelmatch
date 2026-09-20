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

  test('알파는 0~1을 벗어나지 않는다', () {
    for (var i = 0; i <= 200; i++) {
      final t = i / 200;
      evaluateBombLayers(t, values);
      for (final layer in BombLayer.values) {
        expect(_alpha(values, layer), inInclusiveRange(0.0, 1.0));
        expect(_scale(values, layer), inInclusiveRange(0.0, 1.6));
      }
    }
  });

  test('아틀라스 규격 검증은 정수 셀과 실제 치수를 요구한다', () {
    const ok = {
      'imageWidth': 1280,
      'imageHeight': 256,
      'cellSize': 256,
      'layerCount': 5,
      'scale': 3.4,
    };
    expect(
      isValidBombLayerAtlas(
        imageWidth: 1280,
        imageHeight: 256,
        cellSize: 256,
        layerCount: 5,
        scale: 3.4,
      ),
      isTrue,
      reason: '$ok',
    );
    expect(
      isValidBombLayerAtlas(
        imageWidth: 1254,
        imageHeight: 1254,
        cellSize: 313.5,
        layerCount: 5,
        scale: 3.4,
      ),
      isFalse,
      reason: '비정수 셀은 거부한다',
    );
    expect(
      isValidBombLayerAtlas(
        imageWidth: 1024,
        imageHeight: 256,
        cellSize: 256,
        layerCount: 5,
        scale: 3.4,
      ),
      isFalse,
      reason: '치수가 칸 수와 안 맞으면 거부한다',
    );
    expect(
      isValidBombLayerAtlas(
        imageWidth: 1280,
        imageHeight: 512,
        cellSize: 256,
        layerCount: 5,
        scale: 3.4,
      ),
      isFalse,
      reason: '가로 한 줄이 아니면 거부한다',
    );
    expect(
      isValidBombLayerAtlas(
        imageWidth: 1024,
        imageHeight: 256,
        cellSize: 256,
        layerCount: 4,
        scale: 3.4,
      ),
      isFalse,
      reason: '칸 수가 레이어 수와 달라도 거부한다',
    );
    expect(
      isValidBombLayerAtlas(
        imageWidth: 1280,
        imageHeight: 256,
        cellSize: 256,
        layerCount: 5,
        scale: 0,
      ),
      isFalse,
      reason: 'scale이 0이면 거부한다',
    );
  });

  test('manifest의 bomb 항목과 실제 png가 규격을 만족한다', () {
    final manifest =
        jsonDecode(
              File('assets/images/sprites/special_area_effects.json')
                  .readAsStringSync(),
            )
            as Map<String, dynamic>;
    final bomb =
        (manifest['effects'] as Map<String, dynamic>)['bomb']
            as Map<String, dynamic>;
    final png = File('assets/images/${bomb['image']}').readAsBytesSync();
    final header = ByteData.sublistView(png);
    expect(png.sublist(1, 4), orderedEquals('PNG'.codeUnits));
    expect(
      isValidBombLayerAtlas(
        imageWidth: header.getUint32(16),
        imageHeight: header.getUint32(20),
        cellSize: bomb['layerCellSize'] as num,
        layerCount: (bomb['layerCount'] as num).toInt(),
        scale: (bomb['scale'] as num).toDouble(),
      ),
      isTrue,
    );
    // 공용 grid는 hyper와 supernova가 계속 쓴다.
    expect((manifest['grid'] as Map<String, dynamic>)['frameWidth'], 313.5);
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
