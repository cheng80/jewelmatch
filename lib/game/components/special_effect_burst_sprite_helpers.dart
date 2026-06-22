part of 'special_effect_burst.dart';

extension _SpecialEffectBurstSpriteDrawing on SpecialEffectBurst {
  static const double _minimumCoverageCells = 3.35;

  bool _renderAreaEffectSprite(Canvas canvas, double t, double fade) {
    final definition = SpecialEffectBurst._areaEffectAtlas?.definitionFor(
      effectKind,
    );
    if (definition == null || definition.frames.isEmpty) return false;
    if (fade <= 0) return true;

    final tierScale = switch (_tier) {
      0 => 1.0,
      1 => 0.92,
      _ => 0.82,
    };
    final frame = definition.frameFor(t);
    final size =
        tileSize * max(definition.scale * tierScale, _minimumCoverageCells);
    final pixelScale = size / frame.width;
    final center = origin.toOffset() - definition.centerOffset * pixelScale;

    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..blendMode = definition.blendMode;

    canvas.drawImageRect(
      definition.image,
      frame,
      Rect.fromCenter(center: center, width: size, height: size),
      paint,
    );
    return true;
  }
}
