part of 'special_effect_burst.dart';

final Paint _areaLayerPaint = Paint()
  ..blendMode = BlendMode.plus
  ..filterQuality = FilterQuality.medium;

/// 같은 프레임에 켜진 범위 효과들의 레이어를 모아 `drawRawAtlas` 한 번으로 그린다.
/// 레이어는 모두 같은 이미지([BoardAtlas])와 plus 블렌드라, 효과 사이 순서가 바뀌어도
/// 결과가 같다(plus는 교환 가능). 효과(priority 120) 뒤, 주스 레이어(130) 앞에 그린다.
class AreaLayerBatch extends Component {
  AreaLayerBatch() : super(priority: 121);

  // ponytail: 고정 용량. 넘치면 그 효과는 스스로 그린다.
  static const int _capacity = 24 * bombLayerSpriteCount;
  final Float32List _transforms = Float32List(_capacity * 4);
  final Float32List _rects = Float32List(_capacity * 4);
  final Int32List _colors = Int32List(_capacity);
  ui.Image? _image;
  int _count = 0;

  /// 받아들이면 true. 이미지가 다르거나 꽉 찼으면 false라 호출한 쪽이 직접 그린다.
  bool queue(
    ui.Image image,
    Float32List transforms,
    Float32List rects,
    Int32List colors,
  ) {
    if (!isMounted) return false;
    if (_count > 0 && !identical(_image, image)) return false;
    final n = colors.length;
    if (_count + n > _capacity) return false;
    _image = image;
    _transforms.setRange(_count * 4, (_count + n) * 4, transforms);
    _rects.setRange(_count * 4, (_count + n) * 4, rects);
    _colors.setRange(_count, _count + n, colors);
    _count += n;
    return true;
  }

  @override
  void render(Canvas canvas) {
    final image = _image;
    if (_count == 0 || image == null) return;
    canvas.drawRawAtlas(
      image,
      Float32List.sublistView(_transforms, 0, _count * 4),
      Float32List.sublistView(_rects, 0, _count * 4),
      Int32List.sublistView(_colors, 0, _count),
      BlendMode.modulate,
      null,
      _areaLayerPaint,
    );
    _count = 0;
    _image = null;
  }
}

/// 정지 낱장 5칸을 효과별 곡선으로 움직인다. bomb 곡선과 배율은 유지한다.
/// 구운 글로우를 먼저 깔고, 낱장은 `drawRawAtlas`로 태운다([AreaLayerBatch]가 있으면 모아서).
class _AreaLayerRenderer {
  final Float32List _values = Float32List(bombLayerBufferLength);
  final Float32List _transforms = Float32List(bombLayerSpriteCount * 4);
  final Int32List _colors = Int32List(bombLayerSpriteCount);

  void render(
    Canvas canvas,
    _AreaLayerAtlas atlas,
    BakedGlowAtlas glow,
    AreaLayerBatch? batch,
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
    if (batch != null &&
        batch.queue(atlas.image, _transforms, atlas.rects, _colors)) {
      return;
    }
    canvas.drawRawAtlas(
      atlas.image,
      _transforms,
      atlas.rects,
      _colors,
      BlendMode.modulate,
      null,
      _areaLayerPaint,
    );
  }
}

/// [BoardAtlas]에서 한 효과의 레이어 칸 5개를 확인해 담는다.
class _AreaLayerAtlas {
  const _AreaLayerAtlas({
    required this.image,
    required this.rects,
    required this.cellSize,
    required this.scale,
  });

  final ui.Image image;

  /// drawRawAtlas 소스 사각형 5개(left, top, right, bottom). 칸 안쪽 그대로다.
  final Float32List rects;
  final double cellSize;
  final double scale;

  /// `<name>_0`~`<name>_4` 칸이 규격에 맞을 때만 만든다. 아니면 null이다.
  static _AreaLayerAtlas? validated({
    required BoardAtlas atlas,
    required String name,
    required double scale,
  }) {
    final frames = [
      for (var i = 0; i < bombLayerSpriteCount; i++) atlas.frames['${name}_$i'],
    ];
    if (frames.any((f) => f == null)) return null;
    final rects = frames.cast<Rect>();
    if (!isValidAreaLayerFrames(
      frames: rects,
      imageWidth: atlas.image.width,
      imageHeight: atlas.image.height,
      scale: scale,
    )) {
      return null;
    }
    return _AreaLayerAtlas(
      image: atlas.image,
      rects: Float32List.fromList([
        for (final r in rects) ...[r.left, r.top, r.right, r.bottom],
      ]),
      cellSize: rects.first.width,
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
      layerBatch,
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
