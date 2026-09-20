part of 'special_effect_burst.dart';

/// 정지 낱장 5칸을 코드가 움직여 bomb 한 동작을 만든다.
/// 구운 글로우를 먼저 깔고, 낱장은 `drawRawAtlas` 한 번에 태운다.
class _BombLayerRenderer {
  final Float32List _values = Float32List(bombLayerBufferLength);
  final Float32List _transforms = Float32List(bombLayerSpriteCount * 4);
  final Float32List _rects = Float32List(bombLayerSpriteCount * 4);
  final Int32List _colors = Int32List(bombLayerSpriteCount);
  final Paint _paint = Paint()
    ..blendMode = BlendMode.plus
    ..filterQuality = FilterQuality.medium;
  bool _rectsReady = false;

  void render(
    Canvas canvas,
    _BombLayerAtlas atlas,
    BakedGlowAtlas glow,
    Offset center,
    double baseSize,
    double t,
    double fade,
    double glowScale,
  ) {
    evaluateBombLayers(t, _values);

    final glowAlpha = _values[1] * fade * glowScale;
    if (glowAlpha > 0) {
      final radius = baseSize * 0.62 * _values[0];
      glow.radial(
        canvas,
        GlowRadial.bomb,
        center,
        radius,
        Colors.white.withValues(alpha: 0.26 * glowAlpha),
        SpecialEffectBurst._hotYellow.withValues(alpha: 0.42 * glowAlpha),
        SpecialEffectBurst._hotOrange.withValues(alpha: 0.30 * glowAlpha),
      );
    }

    final cell = atlas.cellSize;
    if (!_rectsReady) {
      for (var slot = 0; slot < bombLayerSpriteCount; slot++) {
        _rects[slot * 4] = slot * cell;
        _rects[slot * 4 + 1] = 0;
        _rects[slot * 4 + 2] = (slot + 1) * cell;
        _rects[slot * 4 + 3] = cell;
      }
      _rectsReady = true;
    }

    final anchor = cell / 2;
    var visible = false;
    for (var slot = 0; slot < bombLayerSpriteCount; slot++) {
      final base = (slot + 1) * bombLayerStride;
      final alpha = _values[base + 1] * fade;
      if (alpha <= 0) {
        _transforms[slot * 4] = 0;
        _transforms[slot * 4 + 1] = 0;
        _transforms[slot * 4 + 2] = center.dx;
        _transforms[slot * 4 + 3] = center.dy;
        _colors[slot] = 0;
        continue;
      }
      visible = true;
      final pixelScale = baseSize * _values[base] / cell;
      final angle = _values[base + 2];
      final scos = cos(angle) * pixelScale;
      final ssin = sin(angle) * pixelScale;
      _transforms[slot * 4] = scos;
      _transforms[slot * 4 + 1] = ssin;
      _transforms[slot * 4 + 2] = center.dx - scos * anchor + ssin * anchor;
      _transforms[slot * 4 + 3] = center.dy - ssin * anchor - scos * anchor;
      _colors[slot] = ((alpha * 255).round().clamp(0, 255) << 24) | 0x00FFFFFF;
    }
    if (!visible) return;

    canvas.drawRawAtlas(
      atlas.image,
      _transforms,
      _rects,
      _colors,
      BlendMode.modulate,
      null,
      _paint,
    );
  }
}

/// 정수 셀과 이미지 치수를 확인한 bomb 전용 아틀라스.
class _BombLayerAtlas {
  const _BombLayerAtlas({
    required this.image,
    required this.cellSize,
    required this.scale,
  });

  final ui.Image image;
  final double cellSize;
  final double scale;

  /// manifest 값과 실제 이미지가 맞을 때만 아틀라스를 만든다. 아니면 null이다.
  static _BombLayerAtlas? validated({
    required ui.Image image,
    required num cellSize,
    required int layerCount,
    required double scale,
  }) {
    if (!isValidBombLayerAtlas(
      imageWidth: image.width,
      imageHeight: image.height,
      cellSize: cellSize,
      layerCount: layerCount,
      scale: scale,
    )) {
      return null;
    }
    return _BombLayerAtlas(
      image: image,
      cellSize: cellSize.toDouble(),
      scale: scale,
    );
  }
}
