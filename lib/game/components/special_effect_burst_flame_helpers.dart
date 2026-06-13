part of 'special_effect_burst.dart';

extension _SpecialEffectBurstFlameDrawing on SpecialEffectBurst {
  void _renderFlame(Canvas canvas, double t, double fade) {
    final center = origin.toOffset();
    final heat = Curves.easeOutBack.transform(min(t * 1.15, 1));
    final radius = tileSize * (0.45 + heat * 2.35);

    _drawRadialGlow(
      canvas,
      center,
      radius * 0.88,
      [
        Colors.white.withValues(alpha: 0.18 * fade),
        SpecialEffectBurst._hotYellow.withValues(alpha: 0.24 * fade),
        SpecialEffectBurst._hotOrange.withValues(alpha: 0.13 * fade),
        Colors.transparent,
      ],
      const [0.0, 0.16, 0.48, 1.0],
    );

    _drawExplosionCloud(canvas, center, radius, t, fade);
    _drawFlashStreaks(
      canvas,
      center,
      t,
      fade,
      count: 10,
      length: radius * 0.95,
    );
    _drawSparks(canvas, center, t, fade, count: 42, spread: radius * 1.18);
    _drawEmbers(canvas, center, t, fade, count: 14, spread: radius * 1.05);
    _drawCellFlash(
      canvas,
      t,
      fade,
      maxCells: 9,
      color: SpecialEffectBurst._hotOrange,
    );
  }
}
