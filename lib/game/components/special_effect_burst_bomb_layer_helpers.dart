part of 'special_effect_burst.dart';

/// 정지 낱장 5칸을 효과별 곡선으로 움직인다. bomb 곡선과 배율은 유지한다.
/// 구운 글로우를 먼저 깔고, 낱장은 `drawRawAtlas` 한 번에 태운다.
class _AreaLayerRenderer {
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
    _AreaLayerAtlas atlas,
    BakedGlowAtlas glow,
    Offset center,
    double baseSize,
    double t,
    double fade,
    double glowScale,
    GemKind kind,
  ) {
    switch (kind) {
      case GemKind.hyper:
        evaluateHyperLayers(t, _values);
      case GemKind.supernova:
        evaluateSupernovaLayers(t, _values);
      default:
        evaluateBombLayers(t, _values);
    }

    final glowAlpha = _values[1] * fade * glowScale;
    if (glowAlpha > 0) {
      // 기준 크기가 커져도 글로우의 절대 크기는 거의 그대로 둔다.
      final radius = baseSize * 0.52 * _values[0];
      if (kind == GemKind.bomb) {
        glow.radial(
          canvas,
          GlowRadial.bomb,
          center,
          radius,
          Colors.white.withValues(alpha: 0.26 * glowAlpha),
          SpecialEffectBurst._hotYellow.withValues(alpha: 0.42 * glowAlpha),
          SpecialEffectBurst._hotOrange.withValues(alpha: 0.30 * glowAlpha),
        );
      } else if (kind == GemKind.hyper) {
        glow.radial(
          canvas,
          GlowRadial.hyper,
          center,
          radius,
          Colors.white.withValues(alpha: 0.10 * glowAlpha),
          SpecialEffectBurst._electricBlue.withValues(alpha: 0.24 * glowAlpha),
          SpecialEffectBurst._electricViolet.withValues(
            alpha: 0.18 * glowAlpha,
          ),
        );
      } else {
        glow.radial(
          canvas,
          GlowRadial.supernova,
          center,
          radius,
          Colors.white.withValues(alpha: 0.08 * glowAlpha),
          SpecialEffectBurst._hotYellow.withValues(alpha: 0.23 * glowAlpha),
          SpecialEffectBurst._hotOrange.withValues(alpha: 0.10 * glowAlpha),
        );
      }
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
        // A singular hidden transform can abort later atlas entries on Skia.
        // Keep it invertible and hide it only with transparent modulation.
        _transforms[slot * 4] = 1;
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

/// 정수 셀과 이미지 치수를 확인한 범위 효과 아틀라스.
class _AreaLayerAtlas {
  const _AreaLayerAtlas({
    required this.image,
    required this.cellSize,
    required this.scale,
  });

  final ui.Image image;
  final double cellSize;
  final double scale;

  /// manifest 값과 실제 이미지가 맞을 때만 아틀라스를 만든다. 아니면 null이다.
  static _AreaLayerAtlas? validated({
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
    return _AreaLayerAtlas(
      image: image,
      cellSize: cellSize.toDouble(),
      scale: scale,
    );
  }
}

extension _SpecialEffectAreaLayers on SpecialEffectBurst {
  bool _renderAreaLayers(Canvas canvas, double t, double fade) {
    final atlas = SpecialEffectBurst._layerAtlases[effectKind];
    if (atlas == null) return false;
    final tierScale = effectKind == GemKind.bomb
        ? switch (_tier) {
            0 => 1.0,
            1 => 0.94,
            _ => 0.86,
          }
        : switch (_tier) {
            0 => 1.0,
            1 => 0.92,
            _ => 0.82,
          };
    _areaLayers.render(
      canvas,
      atlas,
      _bakedGlow,
      origin.toOffset(),
      tileSize * atlas.scale * tierScale,
      t,
      fade,
      _glowScale,
      effectKind,
    );
    return true;
  }
}
